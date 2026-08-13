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

        original = module.urlopen
        try:
            module.urlopen = lambda request, timeout=None: Response()
            with self.assertRaises(Exception):
                module.fetch_release("JaceHwang/codex-usage-sidebar", "v0.2.3")
        finally:
            module.urlopen = original

    def test_network_redirect_chain_rejects_intermediate_non_api_host(self):
        spec = importlib.util.spec_from_file_location("snapshot_assets", SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)

        class Response:
            def __init__(self, url): self.url = url
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self): return b"{}"
            def geturl(self): return self.url

        calls = []
        original = module.urlopen
        try:
            def redirecting(request, timeout=None):
                calls.append((request, timeout))
                if len(calls) == 1:
                    return Response("https://evil.example/redirect")
                return Response("https://api.github.com/final")
            module.urlopen = redirecting
            with self.assertRaises(Exception):
                module.fetch_release("JaceHwang/codex-usage-sidebar", "v0.2.3")
        finally:
            module.urlopen = original

    def test_network_request_is_exact_get_with_headers_and_timeout(self):
        spec = importlib.util.spec_from_file_location("snapshot_assets", SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)

        class Response:
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self): return json.dumps(fixture_release()).encode()
            def geturl(self): return "https://api.github.com/repos/JaceHwang/codex-usage-sidebar/releases/tags/v0.2.3"

        seen = {}
        original = module.urlopen
        try:
            def capture(request, timeout=None):
                seen["method"] = request.get_method()
                seen["accept"] = request.get_header("Accept")
                seen["user_agent"] = request.get_header("User-agent")
                seen["authorization"] = request.get_header("Authorization")
                seen["timeout"] = timeout
                return Response()
            module.urlopen = capture
            module.fetch_release("JaceHwang/codex-usage-sidebar", "v0.2.3")
        finally:
            module.urlopen = original
        self.assertEqual(seen["method"], "GET")
        self.assertEqual(seen["accept"], "application/vnd.github+json")
        self.assertEqual(seen["user_agent"], module.USER_AGENT)
        self.assertIsNone(seen["authorization"])
        self.assertIsInstance(seen["timeout"], (int, float))
        self.assertGreater(seen["timeout"], 0)

    def test_rejects_unsafe_repository_and_tag_components(self):
        spec = importlib.util.spec_from_file_location("snapshot_assets", SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        module.validate_identity("owner.with.dot/repository.with.dot", "v0.2.3")
        for repository in ("../foo", "./foo", "foo/..", "foo\\bar", "foo/ bar", "foo/\nbar"):
            with self.subTest(repository=repository):
                with self.assertRaises(Exception):
                    module.validate_identity(repository, "v0.2.3")
        for tag in ("../v", "./v", "v/..", "v 1", "v\\1", "v\n1"):
            with self.subTest(tag=tag):
                with self.assertRaises(Exception):
                    module.validate_identity("JaceHwang/codex-usage-sidebar", tag)

    def test_no_redirect_handler_is_installed_and_rejects_the_first_hop(self):
        spec = importlib.util.spec_from_file_location("snapshot_assets", SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        redirect_handlers = [
            handler
            for handler in module.urlopen.__self__.handlers
            if isinstance(handler, module.urllib_request.HTTPRedirectHandler)
        ]
        self.assertEqual(len(redirect_handlers), 1)
        self.assertIsInstance(redirect_handlers[0], module._NoRedirectHandler)
        request = module.urllib_request.Request("https://api.github.com/example")
        for target in ("https://evil.example/redirect", "https://api.github.com/redirect"):
            with self.subTest(target=target):
                with self.assertRaises(module.SnapshotError):
                    module._NoRedirectHandler().redirect_request(
                        request, None, 302, "Found", {}, target
                    )


if __name__ == "__main__":
    unittest.main()
