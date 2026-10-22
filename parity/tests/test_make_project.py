import importlib.machinery
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "parity" / "make-project.py"


class MakeProjectTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(SCRIPT.is_file(), "the parity project generator is missing")
        loader = importlib.machinery.SourceFileLoader("unity_make_project", str(SCRIPT))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        self.module = importlib.util.module_from_spec(spec)
        sys.modules[loader.name] = self.module
        loader.exec_module(self.module)

    def generate(self, name):
        work = self.tmp / name
        target = work / "project"
        target.parent.mkdir(parents=True)
        self.module.make_project(target)
        return target

    def setUp_temp(self):
        self.ctx = tempfile.TemporaryDirectory()
        self.tmp = Path(self.ctx.name)
        self.addCleanup(self.ctx.cleanup)

    def test_project_matches_the_parity_entrypoint_validators(self):
        self.setUp_temp()
        loader = importlib.machinery.SourceFileLoader(
            "unity_parity_summary_for_make_project", str(ROOT / "scripts" / "parity-summary"))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        summary = importlib.util.module_from_spec(spec)
        sys.modules[loader.name] = summary
        loader.exec_module(summary)
        target = self.generate("validated")
        summary.validate_project(target)
        summary.validate_package(ROOT, target)
        self.assertEqual(self.module.package_files(target / "Packages/com.noisemaker.hlsl"),
                         self.module.package_files(ROOT / "unity/com.noisemaker.hlsl"))

    def test_project_is_deterministic_and_records_no_editor_version(self):
        self.setUp_temp()
        first = self.generate("first")
        second = self.generate("second")
        self.assertEqual(self.module.package_files(first), self.module.package_files(second))
        settings = (first / "ProjectSettings/ProjectSettings.asset").read_text()
        self.assertIn("m_ActiveColorSpace: 1", settings)
        self.assertEqual(json.loads((first / "Packages/manifest.json").read_text()),
                         {"dependencies": {}})
        self.assertFalse((first / "ProjectVersion.txt").exists(),
                         "the generated project must not pin an editor version")
        self.assertTrue((first / "Assets").is_dir() and not any((first / "Assets").iterdir()))

    def test_refuses_a_nonempty_target_and_a_missing_package(self):
        self.setUp_temp()
        occupied = self.tmp / "occupied"
        occupied.mkdir()
        (occupied / "keep").write_text("")
        with self.assertRaises(ValueError):
            self.module.make_project(occupied)
        missing = self.tmp / "missing"
        missing.mkdir()
        real = self.module.PACKAGE
        try:
            self.module.PACKAGE = missing / "nope"
            with self.assertRaises(ValueError):
                self.module.make_project(self.tmp / "elsewhere")
        finally:
            self.module.PACKAGE = real
        self.assertFalse((self.tmp / "elsewhere").exists(),
                         "a failed generation must leave no partial project")


if __name__ == "__main__":
    unittest.main()
