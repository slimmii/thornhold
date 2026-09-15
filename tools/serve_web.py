#!/usr/bin/env python3
"""Build Thornhold and serve its web export on the local network."""

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import ipaddress
import io
import json
from pathlib import Path
import socket
import ssl
import subprocess
import sys
from urllib.parse import parse_qs, urlsplit

from build_web import OUTPUT, ROOT, WEB_FILES


def lan_address(bind):
    if bind != "0.0.0.0":
        return socket.gethostbyname(bind)
    try:
        # Ask the OS which address routes outward; no packets are sent.
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
            probe.connect(("192.0.2.1", 9))
            return probe.getsockname()[0]
    except OSError:
        return socket.gethostbyname(socket.gethostname())


def local_certificate(address):
    address = str(ipaddress.IPv4Address(address))
    directory = ROOT / ".tools" / "lan-tls"
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    (directory.parent / ".gdignore").touch()
    cert = directory / f"{address}.crt"
    key = directory / f"{address}.key"
    if cert.exists() and key.exists():
        valid = subprocess.run(
            ["openssl", "x509", "-in", str(cert), "-checkend", "86400", "-noout"],
            capture_output=True,
        )
        if valid.returncode == 0:
            return cert, key
    subprocess.run([
        "openssl", "req", "-x509", "-newkey", "rsa:2048", "-sha256",
        "-nodes", "-days", "365", "-keyout", str(key), "-out", str(cert),
        "-subj", "/CN=Thornhold LAN",
        "-addext", f"subjectAltName=IP:{address},IP:127.0.0.1,DNS:localhost",
        "-addext", "basicConstraints=critical,CA:FALSE",
        "-addext", "extendedKeyUsage=serverAuth",
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, umask=0o077)
    key.chmod(0o600)
    print(f"Created local HTTPS certificate: {cert}", flush=True)
    return cert, key


class GameServer(ThreadingHTTPServer):
    tls_context = None

    def process_request_thread(self, request, client_address):
        # TLS negotiation must happen in a worker, not in accept(): browsers
        # can preconnect without sending a handshake, blocking all other users.
        try:
            request.settimeout(15)
            if self.tls_context is not None:
                request = self.tls_context.wrap_socket(request, server_side=True)
            request.settimeout(30)
        except (OSError, ssl.SSLError):
            request.close()
            return
        super().process_request_thread(request, client_address)


class GameHandler(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
    }

    def send_head(self):
        url = urlsplit(self.path)
        if url.path in ("/", "/index.html") and parse_qs(url.query).get("diagnostics") == ["1"]:
            html = (Path(self.directory) / "index.html").read_text()
            script = (ROOT / "tools/web_diagnostics.js").read_text()
            html = html.replace('<script src="index.js"></script>',
                                '<script>' + script + '</script><script src="index.js"></script>')
            data = html.encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            return io.BytesIO(data)
        return super().send_head()

    def do_POST(self):
        if self.path != "/__startup_diagnostics":
            self.send_error(404)
            return
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= 8192:
                self.send_error(413)
                return
            # JSON encoding escapes terminal control characters in browser output.
            message = self.rfile.read(size).decode("utf-8", errors="replace")
            print("BROWSER " + self.client_address[0] + " " + json.dumps(message), flush=True)
        except ValueError:
            self.send_error(400)
            return
        self.send_response(204)
        self.end_headers()

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def list_directory(self, path):
        self.send_error(404)
        return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--bind", default="0.0.0.0", help="Listening IPv4 address (default: all interfaces)")
    parser.add_argument("--skip-build", action="store_true", help="Serve the last export without rebuilding")
    parser.add_argument("--godot", help="Godot executable to pass to the web builder")
    parser.add_argument("--cert", type=Path, help="Use an existing HTTPS certificate (with --key)")
    parser.add_argument("--key", type=Path, help="Private key for --cert")
    parser.add_argument("--http", action="store_true", help="HTTP for localhost/SSH tunnels only; requires --bind 127.0.0.1")
    args = parser.parse_args()
    if not 1 <= args.port <= 65535:
        parser.error("--port must be between 1 and 65535")
    if bool(args.cert) != bool(args.key):
        parser.error("--cert and --key must be provided together")
    if args.http and (args.bind != "127.0.0.1" or args.cert):
        parser.error("--http requires --bind 127.0.0.1 and no certificate options")

    # Reserve the port first so an occupied port fails before a lengthy build.
    handler = partial(GameHandler, directory=str(OUTPUT))
    try:
        server = GameServer((args.bind, args.port), handler)
    except OSError as exc:
        parser.exit(1, f"Cannot listen on {args.bind}:{args.port}: {exc}\n")
    with server:
        address = lan_address(args.bind)
        if not args.http:
            try:
                cert, key = (args.cert, args.key) if args.cert else local_certificate(address)
                context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
                context.minimum_version = ssl.TLSVersion.TLSv1_2
                context.load_cert_chain(cert, key)
                server.tls_context = context
            except (OSError, subprocess.CalledProcessError) as exc:
                parser.exit(1, f"HTTPS setup failed (requires OpenSSL or --cert/--key): {exc}\n")
            if not args.cert:
                print("Local certificate: trust it on the playing device before loading the game.", flush=True)
        if not args.skip_build:
            command = [sys.executable, str(ROOT / "tools/build_web.py")]
            if args.godot:
                command.extend(["--godot", args.godot])
            try:
                subprocess.run(command, check=True)
            except subprocess.CalledProcessError as exc:
                parser.exit(exc.returncode, "Web build failed; server was not started.\n")
        missing = [name for name in WEB_FILES if not (OUTPUT / name).is_file()]
        if missing:
            parser.exit(1, "Web export is incomplete. Run again without --skip-build.\n")

        scheme = "http" if args.http else "https"
        if args.bind == "0.0.0.0":
            print(f"This computer: {scheme}://localhost:{args.port}", flush=True)
        print(f"Local network: {scheme}://{address}:{args.port}", flush=True)
        print("Keep this process running while playing. Press Ctrl+C to stop.", flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print("\nServer stopped.")


if __name__ == "__main__":
    main()
