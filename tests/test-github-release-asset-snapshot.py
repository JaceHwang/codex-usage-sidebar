import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "snapshot-github-release-assets.py"


def fixture_release():
    return {
        "id": 123,
        "tag_name": "v0.2.3",
        "assets": [
            {
                "id": 2,
                "name": "zeta.zip",
                "size": 20,
                "digest": "sha256:" + "b" * 64,
                "browser_download_url": "https://github.com/JaceHwang/codex-usage-sidebar/releases/download/v0.2.3/zeta.zip",
            },
            {
                "id": 1,
                "name": "alpha.zip",
                "size": 10,
                "digest": "sha256:" + "a" * 64,
                "browser_download_url": "https://github.com/JaceHwang/codex-usage-sidebar/releases/download/v0.2.3/alpha.zip",
            },
        ],
    }


def run_cli(*args):
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )


class SnapshotTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.input_json = self.root / "release.json"
        self.input_json.write_text(json.dumps(fixture_release()), encoding="utf-8")

    def tearDown(self):
        self.tmp.cleanup()

    def test_snapshot_is_canonical_and_assets_sort_by_name(self):
        output = self.root / "snapshot.json"
        result = run_cli(
            "snapshot",
            "--repository",
            "JaceHwang/codex-usage-sidebar",
            "--tag",
            "v0.2.3",
            "--output",
            str(output),
            "--input-json",
            str(self.input_json),
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(output.read_text(encoding="utf-8")),
            {
                "repository": "JaceHwang/codex-usage-sidebar",
                "tag": "v0.2.3",
                "releaseId": 123,
                "assets": [
                    {
                        "id": 1,
                        "name": "alpha.zip",
                        "size": 10,
                        "digest": "sha256:" + "a" * 64,
                        "browserDownloadUrl": "https://github.com/JaceHwang/codex-usage-sidebar/releases/download/v0.2.3/alpha.zip",
                    },
                    {
                        "id": 2,
                        "name": "zeta.zip",
                        "size": 20,
                        "digest": "sha256:" + "b" * 64,
                        "browserDownloadUrl": "https://github.com/JaceHwang/codex-usage-sidebar/releases/download/v0.2.3/zeta.zip",
                    },
                ],
            },
        )

    def test_compare_accepts_identical_response(self):
        baseline = self.root / "baseline.json"
        created = run_cli(
            "snapshot", "--repository", "JaceHwang/codex-usage-sidebar", "--tag", "v0.2.3",
            "--output", str(baseline), "--input-json", str(self.input_json)
        )
        self.assertEqual(created.returncode, 0, created.stderr)
        result = run_cli(
            "compare", "--baseline", str(baseline), "--repository", "JaceHwang/codex-usage-sidebar",
            "--tag", "v0.2.3", "--input-json", str(self.input_json)
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_compare_rejects_every_identity_mutation(self):
        baseline = self.root / "baseline.json"
        self.assertEqual(run_cli("snapshot", "--repository", "JaceHwang/codex-usage-sidebar", "--tag", "v0.2.3", "--output", str(baseline), "--input-json", str(self.input_json)).returncode, 0)
        mutations = [
            ("release id", lambda d: d.update(id=999)),
            ("tag", lambda d: d.update(tag_name="v9.9.9")),
            ("asset id", lambda d: d["assets"][0].update(id=99)),
            ("asset name", lambda d: d["assets"][0].update(name="renamed.zip")),
            ("asset size", lambda d: d["assets"][0].update(size=999)),
            ("asset digest", lambda d: d["assets"][0].update(digest="sha256:" + "c" * 64)),
            ("asset url", lambda d: d["assets"][0].update(browser_download_url="https://example.invalid/a")),
            ("asset count", lambda d: d["assets"].pop()),
        ]
        for name, mutate in mutations:
            with self.subTest(name=name):
                changed = fixture_release()
                mutate(changed)
                source = self.root / (name.replace(" ", "-") + ".json")
                source.write_text(json.dumps(changed), encoding="utf-8")
                result = run_cli("compare", "--baseline", str(baseline), "--repository", "JaceHwang/codex-usage-sidebar", "--tag", "v0.2.3", "--input-json", str(source))
                self.assertNotEqual(result.returncode, 0)

    def test_invalid_or_missing_digest_fails_and_preserves_output(self):
        output = self.root / "snapshot.json"
        sentinel = '{"sentinel":true}\n'
        output.write_text(sentinel, encoding="utf-8")
        for digest in (None, "sha1:" + "a" * 64, "sha256:NOTHEX"):
            with self.subTest(digest=digest):
                bad = fixture_release()
                if digest is None:
                    del bad["assets"][0]["digest"]
                else:
                    bad["assets"][0]["digest"] = digest
                source = self.root / "bad.json"
                source.write_text(json.dumps(bad), encoding="utf-8")
                result = run_cli("snapshot", "--repository", "JaceHwang/codex-usage-sidebar", "--tag", "v0.2.3", "--output", str(output), "--input-json", str(source))
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(output.read_text(encoding="utf-8"), sentinel)

    def test_network_redirect_to_non_api_host_is_rejected(self):
        spec = importlib.util.spec_from_file_location("snapshot_assets", SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)

        class Response:
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self): return b"{}"
            def geturl(self): return "https://evil.example/releases"

        original = module.urllib_request.urlopen
        try:
            module.urllib_request.urlopen = lambda request: Response()
            with self.assertRaises(Exception):
                module.fetch_release("JaceHwang/codex-usage-sidebar", "v0.2.3")
        finally:
            module.urllib_request.urlopen = original


if __name__ == "__main__":
    unittest.main()
