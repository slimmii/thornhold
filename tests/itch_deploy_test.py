"""Deployment integration checks using isolated exports and a recording Butler stub."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / "tools"))
from build_web import VERSION, WEB_FILES


class ItchDeploymentTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="thornhold deploy test ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        (self.root / "tools").mkdir()
        self.web = self.root / "builds/web"
        self.web.mkdir(parents=True)
        shutil.copy2(PROJECT / "tools/deploy_itch.py", self.root / "tools/deploy_itch.py")
        (self.root / "tools/build_web.py").write_text(
            f"VERSION = {VERSION!r}\nWEB_FILES = {WEB_FILES!r}\n"
            "if __name__ == '__main__':\n"
            "    import os, sys\n"
            "    from pathlib import Path\n"
            "    Path(os.environ['BUILD_MARKER']).touch()\n"
            "    sys.exit(int(os.environ.get('FAKE_BUILD_EXIT', '0')))\n"
        )
        manifest = {"godot": VERSION, "thread_support": False, "files": {}}
        for name in WEB_FILES:
            data = b"GDPC" + b"x" * 500_000 if name == "index.pck" else f"test {name}".encode()
            (self.web / name).write_bytes(data)
            manifest["files"][name] = {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
        (self.web / "build-manifest.json").write_text(json.dumps(manifest))
        self.butler = self.root / "recording butler"
        self.butler.write_text(
            f"#!{sys.executable}\n"
            "import json, os, sys\n"
            "from pathlib import Path\n"
            "record = {'args': sys.argv[1:], 'has_key': bool(os.environ.get('BUTLER_API_KEY'))}\n"
            "record['files'] = sorted(p.name for p in Path(sys.argv[2]).iterdir())\n"
            "Path(os.environ['BUTLER_RECORD']).write_text(json.dumps(record))\n"
            "sys.exit(int(os.environ.get('FAKE_BUTLER_EXIT', '0')))\n"
        )
        self.butler.chmod(0o755)
        self.record = self.root / "butler-call.json"
        self.marker = self.root / "build-called"
        self.env = {key: value for key, value in os.environ.items() if not key.startswith(("ITCH_", "BUTLER_"))}
        self.env.update(CI="false", ITCH_TARGET="test-owner/thornhold", BUTLER_BIN=str(self.butler),
                        BUTLER_RECORD=str(self.record), BUILD_MARKER=str(self.marker))

    def run_deploy(self, *arguments):
        return subprocess.run([sys.executable, str(self.root / "tools/deploy_itch.py"), *arguments],
                              cwd=tempfile.gettempdir(), env=self.env, capture_output=True, text=True)

    def test_build_and_upload_with_environment_configuration(self):
        self.env.update(CI="true", BUTLER_API_KEY="test-secret-never-print", ITCH_CHANNEL="html5-beta", ITCH_VERSION="1.2.3 rc1")
        result = self.run_deploy()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.marker.exists())
        call = json.loads(self.record.read_text())
        self.assertEqual(call["args"], ["push", str(self.root / "builds/itch"), "test-owner/thornhold:html5-beta",
                                       "--if-changed", "--userversion=1.2.3 rc1"])
        self.assertTrue(call["has_key"])
        self.assertNotIn(self.env["BUTLER_API_KEY"], result.stdout + result.stderr + self.record.read_text())

    def test_dry_run_needs_no_credentials_and_cli_overrides_environment(self):
        self.env["CI"] = "true"
        result = self.run_deploy("--skip-build", "--dry-run", "--target", "another/game", "--channel", "html5", "--version", "2.0")
        self.assertEqual(result.returncode, 0, result.stderr)
        call = json.loads(self.record.read_text())
        self.assertFalse(self.marker.exists())
        self.assertFalse(call["has_key"])
        self.assertIn("--dry-run", call["args"])
        self.assertIn("another/game:html5", call["args"])
        self.assertIn("--userversion=2.0", call["args"])

    def test_extra_files_and_old_staging_are_not_uploaded(self):
        for name in (".env", "vercel.json", "debug.log", "source.blend"):
            (self.web / name).write_text("must stay local")
        staged = self.root / "builds/itch"
        staged.mkdir()
        (staged / "stale-file").touch()
        result = self.run_deploy("--skip-build", "--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.record.read_text())["files"], sorted(WEB_FILES))
        with zipfile.ZipFile(self.root / "builds/thornhold-itch.zip") as archive:
            self.assertEqual(sorted(archive.namelist()), sorted(WEB_FILES))
            self.assertIsNone(archive.testzip())

    def test_ci_without_credentials_fails_before_building(self):
        self.env["CI"] = "true"
        result = self.run_deploy()
        self.assertEqual(result.returncode, 2)
        self.assertIn("BUTLER_API_KEY", result.stderr)
        self.assertFalse(self.marker.exists())
        self.assertFalse(self.record.exists())

    def test_invalid_destination_fails_before_building(self):
        for arguments in (("--target", "https://owner.itch.io/game"), ("--channel", "html5:bad")):
            with self.subTest(arguments=arguments):
                self.assertEqual(self.run_deploy(*arguments).returncode, 2)
                self.assertFalse(self.marker.exists())
                self.assertFalse(self.record.exists())

    def test_failed_build_never_uploads_the_old_export(self):
        self.env["FAKE_BUILD_EXIT"] = "23"
        self.assertEqual(self.run_deploy().returncode, 23)
        self.assertTrue(self.marker.exists())
        self.assertFalse(self.record.exists())

    def test_modified_export_preserves_previous_release_and_stops_upload(self):
        (self.web / "index.pck").write_bytes(b"corrupt")
        old = self.root / "builds/itch"
        old.mkdir()
        (old / "previous-release").touch()
        result = self.run_deploy("--skip-build")
        self.assertEqual(result.returncode, 1)
        self.assertIn("checksum mismatch", result.stderr)
        self.assertTrue((old / "previous-release").exists())
        self.assertFalse(self.record.exists())

    def test_missing_runtime_file_stops_upload(self):
        (self.web / "index.audio.worklet.js").unlink()
        self.assertEqual(self.run_deploy("--skip-build").returncode, 1)
        self.assertFalse(self.record.exists())

    def test_threaded_export_stops_upload(self):
        manifest_path = self.web / "build-manifest.json"
        manifest = json.loads(manifest_path.read_text())
        manifest["thread_support"] = True
        manifest_path.write_text(json.dumps(manifest))
        self.assertEqual(self.run_deploy("--skip-build").returncode, 1)
        self.assertFalse(self.record.exists())

    def test_butler_failure_propagates_to_ci(self):
        self.env["FAKE_BUTLER_EXIT"] = "17"
        result = self.run_deploy("--skip-build")
        self.assertEqual(result.returncode, 17)
        self.assertNotIn("push completed", result.stdout)


if __name__ == "__main__":
    unittest.main()
