"""Regression checks for HTTPS connections blocking the LAN server."""

from functools import partial
from pathlib import Path
import socket
import ssl
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch
import urllib.request

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from serve_web import GameHandler, GameServer, local_certificate


class HttpsServerTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory()
        root = Path(cls.directory.name)
        (root / "index.html").write_text("Thornhold test")
        with patch("serve_web.ROOT", root):
            cert, key = local_certificate("127.0.0.1")
        cls.client_context = ssl.create_default_context(cafile=str(cert))
        cls.server = GameServer(
            ("127.0.0.1", 0), partial(GameHandler, directory=str(root))
        )
        cls.server.tls_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        cls.server.tls_context.load_cert_chain(cert, key)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()
        cls.directory.cleanup()

    def fetch(self):
        url = f"https://127.0.0.1:{self.server.server_port}/"
        with urllib.request.urlopen(url, context=self.client_context, timeout=3) as r:
            self.assertEqual(r.read(), b"Thornhold test")

    def test_unfinished_tls_handshake_does_not_block_other_clients(self):
        with socket.create_connection(self.server.server_address, timeout=3):
            self.fetch()

    def test_idle_https_connection_does_not_block_other_clients(self):
        with socket.create_connection(self.server.server_address, timeout=3) as raw:
            with self.client_context.wrap_socket(raw, server_hostname="127.0.0.1"):
                self.fetch()

    def test_plain_http_does_not_break_https(self):
        with socket.create_connection(self.server.server_address, timeout=3) as raw:
            raw.sendall(b"GET / HTTP/1.0\r\n\r\n")
            self.fetch()


if __name__ == "__main__":
    unittest.main()
