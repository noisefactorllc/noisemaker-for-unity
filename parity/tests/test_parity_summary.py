import importlib.machinery
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "parity-summary"


class ParitySummaryTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(SCRIPT.is_file(), "the executable parity entrypoint is missing")
        loader = importlib.machinery.SourceFileLoader("unity_parity_summary", str(SCRIPT))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        self.summary = importlib.util.module_from_spec(spec)
        sys.modules[loader.name] = self.summary
        loader.exec_module(self.summary)

    def test_catalog_covers_each_declared_capture_protocol(self):
        cases = self.summary.catalog(ROOT)
        self.assertEqual(len(cases), 2516)
        self.assertEqual(len({case.id for case in cases}), 2516)
        self.assertIn("upstream/synth3d__cellularAutomata3d", {case.id for case in cases})
        self.assertIn("upstream-tiled/synth3d__cellularAutomata3d", {case.id for case in cases})
        by_id = {case.id: case for case in cases}
        self.assertEqual(by_id["points/points__flow"].protocol.frames, 60)
        self.assertEqual(by_id["param-sweep/points__flow__inputWeight__mid"].protocol.frames, 60)
        self.assertEqual(by_id["param-sweep/render__meshRender__wireframe__wireframe"].protocol.backend, "webgpu")
        self.assertEqual(by_id["param-sweep/filter__pinch__aspectLens__false"].protocol.full_width, 512)
        self.assertEqual(by_id["v104-tiled/mandala_tiled"].protocol.tile_x, 1536)
        self.assertEqual(by_id["v104-tiled/mandala_tiled"].tolerance, 0)
        self.assertEqual(by_id["tile-zoom-budget/zoomBudget"].protocol.size, 512)
        self.assertEqual(by_id["tile-glyph-cap/glyphMap"].protocol.render_scale, 32)
        self.assertTrue(by_id["render/render__meshRender"].protocol.mesh.endswith("sphere.obj"))

    def test_selection_rejects_unknown_duplicate_and_ambiguous_ids(self):
        cases = self.summary.catalog(ROOT)
        for requested in (["unknown"], ["root/blendMode", "root/blendMode"], ["points__flow"]):
            with self.subTest(requested=requested), self.assertRaises(ValueError):
                self.summary.select_cases(cases, requested)
        selected = self.summary.select_cases(cases, ["root/blendMode", "v104-tiled/mandala_tiled"])
        self.assertEqual([case.id for case in selected], ["root/blendMode", "v104-tiled/mandala_tiled"])
        self.assertEqual(len(self.summary.select_cases(cases, [])), 2516)

    def test_real_comparator_defers_bounded_near_until_visual_review(self):
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            cases, env = self.render_fixture(work)
            with patch.dict(os.environ, env):
                records = self.summary.run_batch(ROOT, cases, cases, work / "batch")
            counts = self.summary.count_results(records)
            self.assertEqual(counts, dict(expected=3, executed=3, exact=1, strict=1,
                                          near=0, defer=1, skip=0, fail=0, missing=0))
            near = next(record for record in records if record["name"] == "near")
            self.assertEqual(near["metrics"]["max_abs_diff"], 2)
            self.assertEqual(near["bounds"]["max_abs_diff"], 2)
            self.assertEqual(near["visual_verdict"], "unreviewed")
            self.assertEqual(len(near["golden_sha256"]), 64)
            self.assertTrue(Path(near["candidate"]).is_file())
            self.assertTrue((work / "batch" / "report.json").is_file())
            self.assertTrue((work / "batch" / "commands.json").is_file())

    def test_visual_review_binds_source_authority_protocol_bounds_and_captures(self):
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            cases, env = self.render_fixture(work)
            with patch.dict(os.environ, env):
                records = self.summary.run_batch(ROOT, cases, cases, work / "batch")
            near = next(record for record in records if record["name"] == "near")
            provenance = {"source": {"revision": "a" * 40, "tree_sha256": "b" * 64}, "authority": "c" * 40}
            verdict = {key: near[key] for key in ("protocol", "metrics", "bounds", "golden_sha256", "candidate_sha256")}
            verdict.update(verdict="same", reviewer="independent reviewer")
            receipt = {"schema_version": 1, **provenance, "cases": {"fixture/near": verdict}}
            reviewed = self.summary.apply_visual_review(records, receipt, provenance)
            self.assertEqual(self.summary.count_results(reviewed)["near"], 1)
            self.assertEqual(self.summary.count_results(reviewed)["defer"], 0)
            for field in ("protocol", "metrics", "bounds", "golden_sha256", "candidate_sha256"):
                invalid = json.loads(json.dumps(receipt))
                invalid["cases"]["fixture/near"][field] = "does not match"
                with self.subTest(field=field):
                    result = self.summary.apply_visual_review(records, invalid, provenance)
                    self.assertEqual(self.summary.count_results(result)["defer"], 1)
            for field in ("source", "authority"):
                invalid = {**receipt, field: "does not match"}
                with self.subTest(field=field), self.assertRaises(ValueError):
                    self.summary.apply_visual_review(records, invalid, provenance)

    def test_missing_render_and_failed_runner_cannot_pass(self):
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            cases, env = self.render_fixture(work)
            for mode, field in (("missing", "missing"), ("fail", "fail")):
                with self.subTest(mode=mode), patch.dict(os.environ, {**env, "NM_TEST_RENDER_MODE": mode}):
                    records = self.summary.run_batch(ROOT, cases, cases, work / mode)
                counts = self.summary.count_results(records)
                self.assertGreater(counts[field], 0)
                self.assertLess(counts["exact"] + counts["strict"] + counts["near"], 3)
                if mode == "missing":
                    self.assertEqual(counts["missing"], 1)

    def test_unity_uses_a_writable_gi_cache_inside_retained_evidence(self):
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            cases, env = self.render_fixture(work)
            with patch.dict(os.environ, env):
                self.summary.run_batch(ROOT, cases, cases, work / "batch")
            commands = json.loads((work / "batch/commands.json").read_text())
            self.assertTrue(all(isinstance(command["seconds"], (int, float)) and command["seconds"] >= 0
                                for command in commands))
            unity = next(command["argv"] for command in commands if "-nmManifest" in command["argv"])
            self.assertIn("-giCustomCacheLocation", unity)
            cache = Path(unity[unity.index("-giCustomCacheLocation") + 1])
            self.assertTrue(cache.is_absolute())
            self.assertTrue(cache.is_dir())
            self.assertEqual(cache.parent, (work / "batch").resolve())
            imports = [command for command in commands
                       if "-quit" in command["argv"] and "-nmManifest" not in command["argv"]]
            self.assertEqual(len(imports), 1)
            project = unity[unity.index("-projectPath") + 1]
            self.assertEqual(imports[0]["argv"][imports[0]["argv"].index("-projectPath") + 1], project)
            self.assertEqual(imports[0]["argv"][imports[0]["argv"].index("-giCustomCacheLocation") + 1],
                             unity[unity.index("-giCustomCacheLocation") + 1])
            self.assertTrue((work / "batch/unity-import.log").is_file())

    def test_gamma_runtime_warning_cannot_produce_a_pass(self):
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            cases, env = self.render_fixture(work)
            with patch.dict(os.environ, {**env, "NM_TEST_RENDER_MODE": "gamma"}):
                records = self.summary.run_batch(ROOT, cases, cases, work / "batch")
            counts = self.summary.count_results(records)
            self.assertEqual(counts["fail"], 3)
            self.assertEqual(counts["executed"], 0)

    def test_project_capture_protocol_requires_linear_color(self):
        self.assertTrue(callable(getattr(self.summary, "validate_project", None)),
                        "Linear capture validation is missing")
        with tempfile.TemporaryDirectory() as tmp:
            project = Path(tmp)
            settings = project / "ProjectSettings/ProjectSettings.asset"
            settings.parent.mkdir()
            for text in ("", "  m_ActiveColorSpace: 0\n"):
                settings.write_text(text)
                with self.subTest(text=text), self.assertRaisesRegex(ValueError, "Linear"):
                    self.summary.validate_project(project)
            settings.write_text("  m_ActiveColorSpace: 1\n")
            self.summary.validate_project(project)

    def test_one_out_of_bound_case_does_not_erase_other_case_measurements(self):
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            cases, env = self.render_fixture(work)
            with patch.dict(os.environ, {**env, "NM_TEST_RENDER_MODE": "out-of-bounds"}):
                records = self.summary.run_batch(ROOT, cases, cases, work / "batch")
            self.assertEqual(self.summary.count_results(records),
                             dict(expected=3, executed=3, exact=1, strict=1,
                                  near=0, defer=0, skip=0, fail=1, missing=0))

    def test_cli_failure_prints_the_requested_missing_count_on_its_last_line(self):
        env = {key: value for key, value in os.environ.items() if key not in ("NM_REFERENCE_ROOT", "UNITY_PROJECT")}
        result = subprocess.run([sys.executable, str(SCRIPT), "root/blendMode"],
                                env=env, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        last = result.stdout.splitlines()[-1]
        self.assertTrue(last.startswith("PARITY-SUMMARY "))
        self.assertEqual(json.loads(last.removeprefix("PARITY-SUMMARY ")),
                         dict(expected=1, executed=0, exact=0, strict=0,
                              near=0, defer=0, skip=0, fail=0, missing=1))

    def test_authority_case_changes_cannot_use_stale_port_fixtures(self):
        with tempfile.TemporaryDirectory() as tmp:
            root, ref = Path(tmp) / "port", Path(tmp) / "reference"
            original = ref / "shaders/effects/synth/noise/parity-case.json"
            original.parent.mkdir(parents=True)
            original.write_text(json.dumps({"dsl": "noise().write(o0)"}))
            root.mkdir()
            dsl = root / "noise.dsl"
            dsl.write_text("noise().write(o0)")
            cases = [self.summary.Case("upstream/synth__noise", "synth__noise", str(dsl),
                                       self.summary.Protocol(), 1, 0)]
            self.summary.validate_inputs(root, ref, cases)
            original.write_text(json.dumps({"dsl": "noise(seed: 2).write(o0)"}))
            with self.assertRaisesRegex(ValueError, "authority"):
                self.summary.validate_inputs(root, ref, cases)

    def test_authority_texture_inputs_must_match_the_port_fixture(self):
        with tempfile.TemporaryDirectory() as tmp:
            root, ref = Path(tmp) / "port", Path(tmp) / "reference"
            original = ref / "shaders/effects/synth/media/parity-case.json"
            original.parent.mkdir(parents=True)
            texture = {"effect": "synth/media", "uniform": "imageTex", "width": 1, "height": 1,
                       "data": [255, 0, 0, 255]}
            original.write_text(json.dumps({"dsl": "media().write(o0)", "textureInputs": [texture]}))
            root.mkdir()
            dsl = root / "synth__media.dsl"
            dsl.write_text("media().write(o0)")
            cases = [self.summary.Case("upstream/synth__media", "synth__media", str(dsl),
                                       self.summary.Protocol(), 1, 0)]
            with self.assertRaisesRegex(ValueError, "texture inputs"):
                self.summary.validate_inputs(root, ref, cases)
            (root / "synth__media.textures.json").write_text(json.dumps([texture]))
            self.summary.validate_inputs(root, ref, cases)
            original.write_text(json.dumps({"dsl": "media().write(o0)",
                                            "textureInputs": [dict(texture, data=[0, 0, 255, 255])]}))
            with self.assertRaisesRegex(ValueError, "texture inputs"):
                self.summary.validate_inputs(root, ref, cases)
            original.write_text(json.dumps({"dsl": "media().write(o0)"}))
            with self.assertRaisesRegex(ValueError, "texture inputs"):
                self.summary.validate_inputs(root, ref, cases)

    def test_package_mismatch_and_extra_shader_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "source"
            package = root / "unity/com.noisemaker.hlsl"
            embedded = Path(tmp) / "project/Packages/com.noisemaker.hlsl"
            package.mkdir(parents=True)
            embedded.mkdir(parents=True)
            (package / "shader.hlsl").write_text("current")
            (embedded / "shader.hlsl").write_text("old")
            with self.assertRaisesRegex(ValueError, "package"):
                self.summary.validate_package(root, embedded.parents[1])
            (embedded / "shader.hlsl").write_text("current")
            self.summary.validate_package(root, embedded.parents[1])
            (package / "Shaders").mkdir()
            (embedded / "Shaders.meta").write_text("generated metadata")
            self.summary.validate_package(root, embedded.parents[1])
            (embedded / "extra.hlsl").write_text("unexpected shader")
            with self.assertRaisesRegex(ValueError, "package"):
                self.summary.validate_package(root, embedded.parents[1])

    def test_authority_requires_the_pinned_clean_revision(self):
        with tempfile.TemporaryDirectory() as tmp:
            root, ref = Path(tmp) / "port", Path(tmp) / "reference"
            (root / "scripts").mkdir(parents=True)
            sha = "a" * 40
            (root / "scripts/test").write_text(f'REFERENCE_SHA="{sha}"\n')
            state = {"rev-parse": sha, "status": ""}
            with patch.object(self.summary, "git", side_effect=lambda _root, *args: state[args[0]]):
                self.assertEqual(self.summary.validate_authority(root, ref), sha)
                state["status"] = " M input"
                with self.assertRaisesRegex(ValueError, "clean"):
                    self.summary.validate_authority(root, ref)
                (root / "scripts/test").write_text('REFERENCE_SHA="' + "0" * 40 + '"\n')
                with self.assertRaisesRegex(ValueError, "pinned"):
                    self.summary.validate_authority(root, ref)

    def test_visual_review_rejects_ambiguous_duplicate_keys(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "review.json"
            for document in ('{"schema_version":1,"schema_version":1}',
                             '{"cases":{"fixture/near":{"verdict":"different","verdict":"same"}}}'):
                path.write_text(document)
                with self.subTest(document=document), self.assertRaisesRegex(ValueError, "duplicate"):
                    self.summary.load_visual_review(path)

    def test_source_digest_detects_changes_without_a_new_commit(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root / "shader.hlsl"
            path.write_text("first source")
            with patch.object(self.summary.subprocess, "check_output", return_value=b"shader.hlsl\0"), \
                 patch.object(self.summary, "git", side_effect=lambda _root, *args: "a" * 40 if args[0] == "rev-parse" else ""):
                before = self.summary.source_identity(root)
                path.write_text("changed source")
                after = self.summary.source_identity(root)
            self.assertEqual(after["revision"], before["revision"])
            self.assertNotEqual(after["tree_sha256"], before["tree_sha256"])

    def render_fixture(self, work):
        renderer = work / "renderer"
        renderer.write_text(f"#!{sys.executable}\n" + '''
import os
import sys
from pathlib import Path
from PIL import Image
args = sys.argv[1:]
if '-quit' in args and '-nmManifest' not in args and '-projectPath' in args:
    Path(args[args.index('-logFile') + 1]).write_text('[NMParity] import ok\\n')
    sys.exit(0)
if '-nmManifest' in args:
    mode = os.environ.get('NM_TEST_RENDER_MODE', '')
    manifest = Path(args[args.index('-nmManifest') + 1])
    rows = manifest.read_text().splitlines()
    for row in rows:
        _, output = row.split('\\t')
        name = Path(output).stem
        if mode == 'missing' and name == 'near':
            continue
        delta = {'exact': 0, 'strict': 1, 'near': 2}[name]
        if mode == 'out-of-bounds' and name == 'near':
            delta = 3
        Image.new('RGBA', (8, 8), (100 + delta, 100, 100, 255)).save(output)
    warning = '[NMParity] Project color space is not Linear; parity requires Linear color.\\n' if mode == 'gamma' else ''
    Path(args[args.index('-logFile') + 1]).write_text(warning + f'[NMParity] dsl batch done: {len(rows)} ok, 0 fail\\n')
    sys.exit(1 if mode == 'fail' else 0)
manifest, out = Path(args[1]), Path(args[2])
for row in manifest.read_text().splitlines():
    name, _ = row.split('\\t')
    Image.new('RGBA', (8, 8), (100, 100, 100, 255)).save(out / (name + '.golden.png'))
''')
        renderer.chmod(0o755)
        policy = work / "exceptions.json"
        policy.write_text(json.dumps({"schema_version": 1, "cases": {"near": {
            "max_abs_diff": 2, "ssim_min": 0.99, "max_exceeded_pixels": 64,
            "max_exceeded_channels": 64}}}))
        cases = []
        for name in ("exact", "strict", "near"):
            dsl = work / f"{name}.dsl"
            dsl.write_text("search synth\nnoise().write(o0)\n")
            cases.append(self.summary.Case(f"fixture/{name}", name, str(dsl),
                                          self.summary.Protocol(size=8), 1, 0.99, str(policy)))
        return cases, {"NODE": str(renderer), "UNITY": str(renderer), "UNITY_PROJECT": str(work),
                       "PYTHON": sys.executable, "NM_TEST_RENDER_MODE": ""}


if __name__ == "__main__":
    unittest.main()
