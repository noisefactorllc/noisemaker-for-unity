import copy
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "parity" / "batch-compare.py"
THREE_D_MANIFEST = ROOT / "parity" / "programs" / "3d-manifest.tsv"
THREE_D_EXCEPTIONS = ROOT / "parity" / "programs" / "3d-exceptions.json"
THREE_D_FIXTURES = {
    "filter3dFlow3d",
    "palette3d",
    "synth3dCell3d",
    "synth3dCellularAutomata3d",
    "synth3dFlythrough3d",
    "synth3dFractal3d",
    "synth3dNoise3d",
    "synth3dReactionDiffusion3d",
    "synth3dShape3d",
}
THREE_D_EXCEPTIONS_NAMES = {
    "synth3dCell3d",
    "synth3dFlythrough3d",
    "synth3dFractal3d",
}
CLASSIC_MANIFEST = ROOT / "parity" / "programs" / "classic-manifest.tsv"
CLASSIC_EXCEPTIONS = ROOT / "parity" / "programs" / "classic-exceptions.json"
CLASSIC_FIXTURES = {
    "classicNoisedeck__bitEffects",
    "classicNoisedeck__caustic",
    "classicNoisedeck__cellNoise",
    "classicNoisedeck__coalesce",
    "classicNoisedeck__colorLab",
    "classicNoisedeck__composite",
    "classicNoisedeck__effects",
    "classicNoisedeck__fractal",
    "classicNoisedeck__glitch",
    "classicNoisedeck__kaleido",
    "classicNoisedeck__lensDistortion",
    "classicNoisedeck__moodscape",
    "classicNoisedeck__noise3d",
    "classicNoisedeck__shapeMixer",
    "classicNoisedeck__shapes",
    "classicNoisedeck__shapes3d",
    "classicNoisedeck__splat",
}
SYNTH_MANIFEST = ROOT / "parity" / "programs" / "synth-manifest.tsv"
SYNTH_EXCEPTIONS = ROOT / "parity" / "programs" / "synth-exceptions.json"
SYNTH_FIXTURES = {
    "synth__bitwise",
    "synth__cellularAutomata",
    "synth__curl",
    "synth__gabor",
    "synth__julia",
    "synth__mandelbrot",
    "synth__mnca",
    "synth__modPattern",
    "synth__navierStokes",
    "synth__newton",
    "synth__pattern",
    "synth__polygon",
    "synth__reactionDiffusion",
    "synth__roll",
    "synth__subdivide",
}
MIXER_MANIFEST = ROOT / "parity" / "programs" / "mixer-manifest.tsv"
MIXER_EXCEPTIONS = ROOT / "parity" / "programs" / "mixer-exceptions.json"
MIXER_FIXTURES = {
    "mixer__applyMode",
    "mixer__cellSplit",
    "mixer__centerMask",
    "mixer__channelCombine",
    "mixer__distortion",
    "mixer__focusBlur",
    "mixer__patternMix",
    "mixer__shadow",
    "mixer__shapeMask",
    "mixer__split",
    "mixer__thresholdMix",
    "mixer__uvRemap",
}

POINTS_MANIFEST = ROOT / "parity" / "programs" / "points-manifest.tsv"
POINTS_EXCEPTIONS = ROOT / "parity" / "programs" / "points-exceptions.json"
POINTS_FIXTURES = {
    "points__attractor",
    "points__buddhabrot",
    "points__dla",
    "points__flock",
    "points__flow",
    "points__hydraulic",
    "points__lenia",
    "points__life",
    "points__physarum",
    "points__physical",
}
POINTS_EXCEPTION_CASES = {
    "points__buddhabrot",
    "points__dla",
    "points__flock",
    "points__flow",
    "points__hydraulic",
    "points__lenia",
    "points__life",
    "points__physarum",
}

FILTER_MANIFEST = ROOT / "parity" / "programs" / "filter-manifest.tsv"
FILTER_EXCEPTIONS = ROOT / "parity" / "programs" / "filter-exceptions.json"
FILTER_FIXTURES = {
    "filter__bloom",
    "filter__bulge",
    "filter__celShading",
    "filter__channel",
    "filter__chroma",
    "filter__chromaticAberration",
    "filter__clouds",
    "filter__colorReplace",
    "filter__convolutionFeedback",
    "filter__corrupt",
    "filter__crt",
    "filter__degauss",
    "filter__deriv",
    "filter__feedback",
    "filter__fibers",
    "filter__flipMirror",
    "filter__fxaa",
    "filter__glowingEdge",
    "filter__glyphMap",
    "filter__grain",
    "filter__grime",
    "filter__historicPalette",
    "filter__lens",
    "filter__lensWarp",
    "filter__lightLeak",
    "filter__motionBlur",
    "filter__normalMap",
    "filter__normalize",
    "filter__octaveWarp",
    "filter__osd",
    "filter__outline",
    "filter__palette",
    "filter__pinch",
    "filter__pixelSort",
    "filter__pixels",
    "filter__polar",
    "filter__posterize",
    "filter__prismaticAberration",
    "filter__reindex",
    "filter__repeat",
    "filter__reverb",
    "filter__ridge",
    "filter__rotate",
    "filter__scale",
    "filter__scanlineError",
    "filter__scratches",
    "filter__scroll",
    "filter__seamless",
    "filter__sharpen",
    "filter__sine",
}
FILTER_EXCEPTION_CASES = {
    "filter__convolutionFeedback",
    "filter__crt",
    "filter__degauss",
    "filter__lensWarp",
    "filter__octaveWarp",
    "filter__pinch",
    "filter__polar",
    "filter__posterize",
    "filter__reindex",
    "filter__rotate",
    "filter__scanlineError",
}


def write_png(path, rgba, size=(16, 16), changed=None):
    image = Image.new("RGBA", size, rgba)
    if changed:
        for x, y, color in changed:
            image.putpixel((x, y), color)
    image.save(path)


def run_compare(gold, cand, report, *extra):
    completed = subprocess.run(
        [
            sys.executable,
            str(SCRIPT),
            str(gold),
            str(cand),
            "--out",
            str(report),
            "--tolerance",
            "1",
            "--ssim-min",
            "0.98",
            *extra,
        ],
        text=True,
        capture_output=True,
        check=False,
    )
    data = json.loads(report.read_text()) if report.exists() else None
    return completed, data


def exception_document(case_name="sample", **overrides):
    bounds = {
        "max_abs_diff": 2,
        "ssim_min": 0.99,
        "max_exceeded_pixels": 1,
        "max_exceeded_channels": 1,
        "allowed_exceeded_pixels": [[3, 4]],
    }
    bounds.update(overrides)
    return {"schema_version": 1, "cases": {case_name: bounds}}


class BatchCompareContractTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name)
        self.gold = self.root / "gold"
        self.cand = self.root / "cand"
        self.gold.mkdir()
        self.cand.mkdir()
        self.run_number = 0

    def tearDown(self):
        self.temporary_directory.cleanup()

    def write_pair(self, candidate_changes=None, golden_size=(16, 16), candidate_size=(16, 16)):
        write_png(
            self.gold / "sample.golden.png",
            (127, 127, 127, 255),
            size=golden_size,
        )
        write_png(
            self.cand / "sample.png",
            (127, 127, 127, 255),
            size=candidate_size,
            changed=candidate_changes,
        )

    def write_exception(self, document, name="exceptions.json"):
        path = self.root / name
        if isinstance(document, str):
            path.write_text(document)
        else:
            path.write_text(json.dumps(document))
        return path

    def write_manifest(self, lines):
        path = self.root / "manifest.tsv"
        path.write_text("\n".join(lines) + "\n")
        return path

    def compare(self, *extra):
        self.run_number += 1
        report = self.root / f"report-{self.run_number}.json"
        return run_compare(self.gold, self.cand, report, *extra)

    def assert_single_result(self, data, expected_class):
        self.assertIsNotNone(data)
        self.assertEqual(len(data["results"]), 1)
        self.assertEqual(data["results"][0]["cls"], expected_class)
        return data["results"][0]

    def test_within_tolerance_passes(self):
        self.write_pair([(3, 4, (128, 127, 127, 255))])

        completed, data = self.compare()

        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assert_single_result(data, "PASS")
        self.assertEqual(data["counts"], {"PASS": 1})

    def test_near_without_exception_fails(self):
        self.write_pair([(3, 4, (129, 127, 127, 255))])

        completed, data = self.compare()

        self.assertEqual(completed.returncode, 1)
        result = self.assert_single_result(data, "NEAR")
        self.assertEqual(result["exceeded_pixel_coordinates"], [[3, 4]])

    def test_fully_bounded_near_is_allowed(self):
        self.write_pair([(3, 4, (129, 127, 127, 255))])
        exceptions = self.write_exception(exception_document())

        completed, data = self.compare("--exceptions", str(exceptions))

        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assert_single_result(data, "ALLOWED_NEAR")
        self.assertEqual(data["counts"], {"ALLOWED_NEAR": 1})

    def test_manifest_exact_fixture_set_passes(self):
        self.write_pair()
        manifest = self.write_manifest(["sample\tparity/programs/noise.dsl"])

        completed, data = self.compare("--manifest", str(manifest))

        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assert_single_result(data, "PASS")

    def test_manifest_rejects_duplicate_fixture_name_or_path(self):
        self.write_pair()
        duplicate_manifests = {
            "name": [
                "sample\tparity/programs/noise.dsl",
                "sample\tparity/programs/solid.dsl",
            ],
            "path": [
                "sample\tparity/programs/noise.dsl",
                "other\tparity/programs/noise.dsl",
            ],
        }

        for label, lines in duplicate_manifests.items():
            with self.subTest(label=label):
                manifest = self.write_manifest(lines)
                completed, data = self.compare("--manifest", str(manifest))
                self.assertEqual(completed.returncode, 2)
                self.assertIsNone(data)
                self.assertIn(f"duplicate fixture {label}", completed.stderr)

    def test_manifest_rejects_non_tsv_or_missing_dsl_path(self):
        self.write_pair()
        invalid_manifests = {
            "tab separator": ["sample parity/programs/noise.dsl"],
            "missing DSL": ["sample\tparity/programs/does-not-exist.dsl"],
        }

        for label, lines in invalid_manifests.items():
            with self.subTest(label=label):
                manifest = self.write_manifest(lines)
                completed, data = self.compare("--manifest", str(manifest))
                self.assertEqual(completed.returncode, 2)
                self.assertIsNone(data)
                self.assertIn("invalid fixture manifest", completed.stderr)

    def test_manifest_rejects_missing_or_extra_fixture_images(self):
        self.write_pair()
        cases = {
            "missing golden": (
                ["sample\tparity/programs/noise.dsl", "other\tparity/programs/solid.dsl"],
                "missing golden fixtures: other",
            ),
            "missing candidate": (
                ["sample\tparity/programs/noise.dsl", "other\tparity/programs/solid.dsl"],
                "missing candidate fixtures: other",
            ),
            "extra golden": (
                ["other\tparity/programs/solid.dsl"],
                "unexpected golden fixtures: sample",
            ),
            "extra candidate": (
                ["other\tparity/programs/solid.dsl"],
                "unexpected candidate fixtures: sample",
            ),
        }

        for label, (lines, expected) in cases.items():
            with self.subTest(label=label):
                if label == "missing golden":
                    write_png(self.cand / "other.png", (127, 127, 127, 255))
                elif label == "missing candidate":
                    write_png(self.gold / "other.golden.png", (127, 127, 127, 255))
                manifest = self.write_manifest(lines)
                completed, data = self.compare("--manifest", str(manifest))
                self.assertEqual(completed.returncode, 2)
                self.assertIsNone(data)
                self.assertIn(expected, completed.stderr)
                for path in (
                    self.gold / "other.golden.png",
                    self.cand / "other.png",
                ):
                    path.unlink(missing_ok=True)

    def test_exception_rejects_max_diff_overrun(self):
        self.write_pair([(3, 4, (129, 127, 127, 255))])
        exceptions = self.write_exception(exception_document(max_abs_diff=1))

        completed, data = self.compare("--exceptions", str(exceptions))

        self.assertEqual(completed.returncode, 1)
        self.assert_single_result(data, "NEAR")

    def test_exception_rejects_ssim_floor_overrun(self):
        self.write_pair([(3, 4, (129, 127, 127, 255))])
        exceptions = self.write_exception(exception_document(ssim_min=1.0))

        completed, data = self.compare("--exceptions", str(exceptions))

        self.assertEqual(completed.returncode, 1)
        self.assert_single_result(data, "NEAR")

    def test_exception_rejects_mean_diff_overrun(self):
        self.write_pair([(3, 4, (129, 127, 127, 255))])
        exceptions = self.write_exception(
            exception_document(
                max_mean_abs_diff=0.001,
                mechanism="A verified deterministic floating-point boundary tie.",
            )
        )

        completed, data = self.compare("--exceptions", str(exceptions))

        self.assertEqual(completed.returncode, 1)
        self.assert_single_result(data, "NEAR")

    def test_exception_rejects_pixel_count_overrun(self):
        self.write_pair(
            [
                (3, 4, (129, 127, 127, 255)),
                (5, 6, (129, 127, 127, 255)),
            ]
        )
        exceptions = self.write_exception(
            exception_document(
                max_exceeded_pixels=1,
                max_exceeded_channels=2,
                allowed_exceeded_pixels=[[3, 4], [5, 6]],
            )
        )

        completed, data = self.compare("--exceptions", str(exceptions))

        self.assertEqual(completed.returncode, 1)
        self.assert_single_result(data, "NEAR")

    def test_exception_rejects_channel_count_overrun(self):
        self.write_pair([(3, 4, (129, 129, 127, 255))])
        exceptions = self.write_exception(exception_document(max_exceeded_channels=1))

        completed, data = self.compare("--exceptions", str(exceptions))

        self.assertEqual(completed.returncode, 1)
        self.assert_single_result(data, "NEAR")

    def test_exception_rejects_coordinate_change(self):
        self.write_pair([(3, 4, (129, 127, 127, 255))])
        exceptions = self.write_exception(
            exception_document(allowed_exceeded_pixels=[[4, 3]])
        )

        completed, data = self.compare("--exceptions", str(exceptions))

        self.assertEqual(completed.returncode, 1)
        self.assert_single_result(data, "NEAR")

    def test_fail_cannot_be_allowlisted(self):
        write_png(self.gold / "sample.golden.png", (0, 0, 0, 255))
        write_png(self.cand / "sample.png", (255, 255, 255, 255))
        exceptions = self.write_exception(
            exception_document(
                max_abs_diff=255,
                max_exceeded_pixels=256,
                max_exceeded_channels=768,
                allowed_exceeded_pixels=None,
            )
        )
        document = json.loads(exceptions.read_text())
        del document["cases"]["sample"]["allowed_exceeded_pixels"]
        exceptions.write_text(json.dumps(document))

        completed, data = self.compare("--exceptions", str(exceptions))

        self.assertEqual(completed.returncode, 1)
        self.assert_single_result(data, "FAIL")

    def test_missing_candidate_fails(self):
        write_png(self.gold / "sample.golden.png", (127, 127, 127, 255))

        completed, data = self.compare()

        self.assertEqual(completed.returncode, 1)
        self.assert_single_result(data, "MISSING_CAND")

    def test_missing_golden_fails(self):
        write_png(self.cand / "sample.png", (127, 127, 127, 255))

        completed, data = self.compare()

        self.assertEqual(completed.returncode, 1)
        self.assert_single_result(data, "MISSING_GOLD")

    def test_size_mismatch_fails(self):
        self.write_pair(candidate_size=(8, 8))

        completed, data = self.compare()

        self.assertEqual(completed.returncode, 1)
        self.assert_single_result(data, "SIZE_MISMATCH")

    def test_empty_directories_fail(self):
        completed, data = self.compare()

        self.assertEqual(completed.returncode, 1)
        self.assertEqual(data["counts"], {})
        self.assertEqual(data["results"], [])
        self.assertEqual(data["unused_exceptions"], [])

    def test_invalid_exception_documents_are_configuration_errors(self):
        self.write_pair([(3, 4, (129, 127, 127, 255))])
        valid = exception_document()
        invalid_documents = [
            ("malformed JSON", "{"),
            ("root is not an object", []),
        ]

        def invalid(label, mutate):
            document = copy.deepcopy(valid)
            mutate(document)
            invalid_documents.append((label, document))

        invalid("unsupported schema version", lambda d: d.update(schema_version=2))
        invalid("boolean schema version", lambda d: d.update(schema_version=True))
        invalid("missing root key", lambda d: d.pop("cases"))
        invalid("extra root key", lambda d: d.update(extra=True))
        invalid("cases is not an object", lambda d: d.update(cases=[]))
        invalid("empty case name", lambda d: d.update(cases={"": d["cases"]["sample"]}))
        invalid("case is not an object", lambda d: d.update(cases={"sample": []}))
        invalid(
            "missing case field",
            lambda d: d["cases"]["sample"].pop("max_abs_diff"),
        )
        invalid("extra case field", lambda d: d["cases"]["sample"].update(extra=1))
        for field in (
            "max_abs_diff",
            "ssim_min",
            "max_exceeded_pixels",
            "max_exceeded_channels",
        ):
            invalid(
                f"boolean {field}",
                lambda d, field=field: d["cases"]["sample"].update({field: True}),
            )
        invalid(
            "negative max diff",
            lambda d: d["cases"]["sample"].update(max_abs_diff=-1),
        )
        invalid(
            "max diff above byte range",
            lambda d: d["cases"]["sample"].update(max_abs_diff=256),
        )
        invalid(
            "non-finite max diff",
            lambda d: d["cases"]["sample"].update(max_abs_diff=float("inf")),
        )
        invalid(
            "non-numeric max diff",
            lambda d: d["cases"]["sample"].update(max_abs_diff="2"),
        )
        invalid(
            "negative mean diff",
            lambda d: d["cases"]["sample"].update(max_mean_abs_diff=-0.1),
        )
        invalid(
            "empty mechanism",
            lambda d: d["cases"]["sample"].update(mechanism=""),
        )
        invalid(
            "negative ssim",
            lambda d: d["cases"]["sample"].update(ssim_min=-0.1),
        )
        invalid(
            "ssim above one",
            lambda d: d["cases"]["sample"].update(ssim_min=1.1),
        )
        invalid(
            "ssim below global threshold",
            lambda d: d["cases"]["sample"].update(ssim_min=0.97),
        )
        invalid(
            "fractional pixel count",
            lambda d: d["cases"]["sample"].update(max_exceeded_pixels=1.5),
        )
        invalid(
            "negative channel count",
            lambda d: d["cases"]["sample"].update(max_exceeded_channels=-1),
        )
        invalid(
            "coordinates not an array",
            lambda d: d["cases"]["sample"].update(allowed_exceeded_pixels={}),
        )
        invalid(
            "coordinate wrong length",
            lambda d: d["cases"]["sample"].update(allowed_exceeded_pixels=[[3]]),
        )
        invalid(
            "coordinate bool",
            lambda d: d["cases"]["sample"].update(allowed_exceeded_pixels=[[True, 4]]),
        )
        invalid(
            "coordinate negative",
            lambda d: d["cases"]["sample"].update(allowed_exceeded_pixels=[[-1, 4]]),
        )
        invalid(
            "duplicate coordinates",
            lambda d: d["cases"]["sample"].update(
                allowed_exceeded_pixels=[[3, 4], [3, 4]]
            ),
        )

        for index, (label, document) in enumerate(invalid_documents):
            with self.subTest(label=label):
                path = self.write_exception(document, f"invalid-{index}.json")
                completed, data = self.compare("--exceptions", str(path))
                self.assertEqual(completed.returncode, 2)
                self.assertIsNone(data)
                self.assertIn("invalid exceptions document", completed.stderr)

    def test_unknown_exception_case_is_configuration_error(self):
        self.write_pair([(3, 4, (129, 127, 127, 255))])
        exceptions = self.write_exception(exception_document(case_name="typo"))

        completed, data = self.compare("--exceptions", str(exceptions))

        self.assertEqual(completed.returncode, 2)
        self.assertIsNone(data)
        self.assertIn("unknown exception case", completed.stderr)

    def test_passing_allowlisted_case_is_reported_unused(self):
        self.write_pair()
        exceptions = self.write_exception(exception_document())

        completed, data = self.compare("--exceptions", str(exceptions))

        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assert_single_result(data, "PASS")
        self.assertEqual(data["unused_exceptions"], ["sample"])
        self.assertIn("unused exception: sample", completed.stdout)

    def test_manifest_mode_rejects_unused_exception(self):
        self.write_pair()
        manifest = self.write_manifest(["sample\tparity/programs/noise.dsl"])
        exceptions = self.write_exception(exception_document())

        completed, data = self.compare(
            "--manifest", str(manifest), "--exceptions", str(exceptions)
        )

        self.assertEqual(completed.returncode, 1)
        self.assert_single_result(data, "PASS")
        self.assertEqual(data["unused_exceptions"], ["sample"])

    def test_report_contains_raw_exceeded_metrics_and_counts(self):
        self.write_pair([(3, 4, (129, 127, 127, 255))])

        completed, data = self.compare()

        self.assertEqual(completed.returncode, 1)
        self.assertEqual(set(data), {"counts", "results", "unused_exceptions"})
        self.assertEqual(data["counts"], {"NEAR": 1})
        result = data["results"][0]
        self.assertEqual(result["max_abs_diff"], 2.0)
        self.assertEqual(result["mean_abs_diff"], 2.0 / (16 * 16 * 4))
        self.assertEqual(result["exceeded_pixels"], 1)
        self.assertEqual(result["exceeded_channels"], 1)
        self.assertEqual(result["exceeded_pixel_coordinates"], [[3, 4]])
        self.assertNotEqual(result["ssim"], round(result["ssim"], 5))


class Repository3dPolicyContractTests(unittest.TestCase):
    def test_single_and_batch_exporters_use_the_full_clean_start_protocol(self):
        single = (ROOT / "parity" / "export-and-render.mjs").read_text()
        batch = (ROOT / "parity" / "batch-golden.mjs").read_text()

        for source in (single, batch):
            self.assertIn("p.graph.id !== base && p.isCompiling === false", source)
            self.assertIn("}, baselineId, { timeout: STATUS_TIMEOUT })", source)
            self.assertIn("for (const texId of backend.textures.keys())", source)
            self.assertIn("backend.clearTexture(texId)", source)
            self.assertIn("surface.read = readId", source)
            self.assertIn("surface.write = writeId", source)
            self.assertIn("p.frameIndex = 0", source)
            self.assertIn("p.lastTime = 0", source)
            self.assertLess(
                source.index("if (window.__noisemakerSetPausedTime)"),
                source.index("p.lastTime = 0"),
            )

    def test_repository_exposes_an_executable_3d_gate(self):
        gate = ROOT / "parity" / "3d-verify.sh"

        self.assertTrue(gate.is_file())
        source = gate.read_text()
        for required in (
            "3d-manifest.tsv",
            "3d-exceptions.json",
            "batch-golden.mjs",
            "RenderDslBatchFromCommandLine",
            "--manifest",
            "--exceptions",
        ):
            self.assertIn(required, source)

    def test_repository_3d_manifest_and_policy_are_exact(self):
        manifest_lines = [
            line.split()
            for line in THREE_D_MANIFEST.read_text().splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        ]
        self.assertEqual(len(manifest_lines), 9)
        self.assertTrue(all(len(parts) == 2 for parts in manifest_lines))
        self.assertEqual({parts[0] for parts in manifest_lines}, THREE_D_FIXTURES)
        self.assertEqual(
            {Path(parts[1]).stem for parts in manifest_lines}, THREE_D_FIXTURES
        )
        self.assertTrue(all((ROOT / parts[1]).is_file() for parts in manifest_lines))

        policy = json.loads(THREE_D_EXCEPTIONS.read_text())
        self.assertEqual(1, policy["schema_version"])
        self.assertEqual(
            {
                "synth3dCell3d": {
                    "max_abs_diff": 91,
                    "max_mean_abs_diff": 0.000847,
                    "ssim_min": 0.999989,
                    "max_exceeded_pixels": 1,
                    "max_exceeded_channels": 3,
                    "allowed_exceeded_pixels": [[204, 108]],
                    "mechanism": "Sparse float32 nearest-cell boundary tie in the 3D cellular density field at one shared-surface pixel.",
                },
                "synth3dFlythrough3d": {
                    "max_abs_diff": 189,
                    "max_mean_abs_diff": 0.581727,
                    "ssim_min": 0.993903,
                    "max_exceeded_pixels": 4695,
                    "max_exceeded_channels": 9851,
                    "mechanism": "Collision-avoidance camera-origin amplification of float32 transcendental and distance-estimator gradient drift; only 62 foreground-mask pixels flip.",
                },
                "synth3dFractal3d": {
                    "max_abs_diff": 147,
                    "max_mean_abs_diff": 0.021836,
                    "ssim_min": 0.999845,
                    "max_exceeded_pixels": 136,
                    "max_exceeded_channels": 408,
                    "mechanism": "Sparse float32 raymarch and iteration boundary ties in the transcendental fractal distance estimator.",
                },
            },
            policy["cases"],
        )

    def test_repository_3d_policy_is_exercised_by_the_real_grader(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            gold = root / "gold"
            cand = root / "cand"
            gold.mkdir()
            cand.mkdir()
            for name in THREE_D_FIXTURES:
                changed = None
                if name == "synth3dCell3d":
                    changed = [(204, 108, (130, 127, 127, 255))]
                elif name in {"synth3dFlythrough3d", "synth3dFractal3d"}:
                    changed = [(0, 0, (130, 127, 127, 255))]
                write_png(gold / f"{name}.golden.png", (127, 127, 127, 255), size=(256, 256))
                write_png(cand / f"{name}.png", (127, 127, 127, 255), size=(256, 256), changed=changed)

            completed, report = run_compare(
                gold,
                cand,
                root / "report.json",
                "--manifest",
                str(THREE_D_MANIFEST),
                "--exceptions",
                str(THREE_D_EXCEPTIONS),
            )

        self.assertEqual(0, completed.returncode, completed.stderr)
        self.assertEqual({"PASS": 6, "ALLOWED_NEAR": 3}, report["counts"])
        self.assertEqual([], report["unused_exceptions"])


class RepositoryClassicPolicyContractTests(unittest.TestCase):
    def test_repository_exposes_an_executable_classic_gate(self):
        gate = ROOT / "parity" / "classic-verify.sh"
        self.assertTrue(gate.is_file())
        source = gate.read_text()
        for required in (
            "classic-manifest.tsv",
            "classic-exceptions.json",
            "batch-golden.mjs",
            "RenderDslBatchFromCommandLine",
            "--manifest",
            "--exceptions",
        ):
            self.assertIn(required, source)

    def test_repository_classic_manifest_and_policy_are_exact(self):
        manifest_lines = [
            line.split("\t")
            for line in CLASSIC_MANIFEST.read_text().splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        ]
        self.assertEqual(len(manifest_lines), 17)
        self.assertTrue(all(len(parts) == 2 for parts in manifest_lines))
        self.assertEqual({parts[0] for parts in manifest_lines}, CLASSIC_FIXTURES)
        self.assertTrue(all((ROOT / parts[1]).is_file() for parts in manifest_lines))

        policy = json.loads(CLASSIC_EXCEPTIONS.read_text())
        self.assertEqual(1, policy["schema_version"])
        self.assertEqual(
            {
                "classicNoisedeck__fractal": {
                    "max_abs_diff": 148,
                    "ssim_min": 0.9999,
                    "max_exceeded_pixels": 31,
                    "max_exceeded_channels": 93,
                    "mechanism": "Complex-plane escape boundary iteration threshold tie (transcendental float32 precision).",
                },
                "classicNoisedeck__kaleido": {
                    "max_abs_diff": 16,
                    "ssim_min": 0.9999,
                    "max_exceeded_pixels": 80,
                    "max_exceeded_channels": 192,
                    "mechanism": "Bilinear sampling / wrap coordinate tie at mirror-fold symmetry seams (transcendental float32 precision).",
                },
            },
            policy["cases"],
        )

    def test_repository_classic_policy_is_exercised_by_the_real_grader(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            gold = root / "gold"
            cand = root / "cand"
            gold.mkdir()
            cand.mkdir()
            for name in CLASSIC_FIXTURES:
                changed = None
                if name == "classicNoisedeck__fractal":
                    changed = [(0, 0, (130, 127, 127, 255))]
                elif name == "classicNoisedeck__kaleido":
                    changed = [(1, 1, (130, 127, 127, 255))]
                write_png(gold / f"{name}.golden.png", (127, 127, 127, 255), size=(256, 256))
                write_png(cand / f"{name}.png", (127, 127, 127, 255), size=(256, 256), changed=changed)

            completed, report = run_compare(
                gold,
                cand,
                root / "report.json",
                "--manifest",
                str(CLASSIC_MANIFEST),
                "--exceptions",
                str(CLASSIC_EXCEPTIONS),
            )

        self.assertEqual(0, completed.returncode, completed.stderr)
        self.assertIsNotNone(report)
        assert report is not None
        self.assertEqual({"PASS": 15, "ALLOWED_NEAR": 2}, report["counts"])
        self.assertEqual([], report["unused_exceptions"])


class RepositorySynthPolicyContractTests(unittest.TestCase):
    def test_repository_exposes_an_executable_synth_gate(self):
        gate = ROOT / "parity" / "synth-verify.sh"
        self.assertTrue(gate.is_file())
        source = gate.read_text()
        for required in (
            "synth-manifest.tsv",
            "synth-exceptions.json",
            "batch-golden.mjs",
            "RenderDslBatchFromCommandLine",
            "--manifest",
            "--exceptions",
        ):
            self.assertIn(required, source)

    def test_repository_synth_manifest_and_policy_are_exact(self):
        manifest_lines = [
            line.split("\t")
            for line in SYNTH_MANIFEST.read_text().splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        ]
        self.assertEqual(len(manifest_lines), 15)
        self.assertTrue(all(len(parts) == 2 for parts in manifest_lines))
        self.assertEqual({parts[0] for parts in manifest_lines}, SYNTH_FIXTURES)
        self.assertTrue(all((ROOT / parts[1]).is_file() for parts in manifest_lines))

        policy = json.loads(SYNTH_EXCEPTIONS.read_text())
        self.assertEqual(1, policy["schema_version"])
        self.assertEqual(
            {
                "synth__julia": {
                    "max_abs_diff": 251,
                    "max_mean_abs_diff": 0.07,
                    "ssim_min": 0.92,
                    "max_exceeded_pixels": 184,
                    "max_exceeded_channels": 552,
                    "mechanism": "Iterative escape-time boundary classification is chaotic under cross-backend floating-point rounding at the set boundary.",
                },
                "synth__mandelbrot": {
                    "max_abs_diff": 225,
                    "max_mean_abs_diff": 0.10,
                    "ssim_min": 0.92,
                    "max_exceeded_pixels": 130,
                    "max_exceeded_channels": 390,
                    "mechanism": "Iterative escape-time boundary classification is chaotic under cross-backend floating-point rounding at the set boundary; low-luminance field amplifies relative SSIM impact of 130 boundary pixels.",
                },
                "synth__newton": {
                    "max_abs_diff": 252,
                    "max_mean_abs_diff": 0.11,
                    "ssim_min": 0.92,
                    "max_exceeded_pixels": 127,
                    "max_exceeded_channels": 381,
                    "mechanism": "Iterative root-basin boundary classification is chaotic under cross-backend floating-point rounding at basin fractal boundaries.",
                },
            },
            policy["cases"],
        )

    def test_repository_synth_policy_is_exercised_by_the_real_grader(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            gold = root / "gold"
            cand = root / "cand"
            gold.mkdir()
            cand.mkdir()
            for name in SYNTH_FIXTURES:
                changed = None
                if name == "synth__julia":
                    changed = [(0, 0, (130, 127, 127, 255))]
                elif name == "synth__mandelbrot":
                    changed = [(1, 1, (130, 127, 127, 255))]
                elif name == "synth__newton":
                    changed = [(2, 2, (130, 127, 127, 255))]
                write_png(gold / f"{name}.golden.png", (127, 127, 127, 255), size=(256, 256))
                write_png(cand / f"{name}.png", (127, 127, 127, 255), size=(256, 256), changed=changed)

            completed, report = run_compare(
                gold,
                cand,
                root / "report.json",
                "--manifest",
                str(SYNTH_MANIFEST),
                "--exceptions",
                str(SYNTH_EXCEPTIONS),
                "--ssim-min",
                "0.92",
            )

        self.assertEqual(0, completed.returncode, completed.stderr)
        self.assertIsNotNone(report)
        assert report is not None
        self.assertEqual({"PASS": 12, "ALLOWED_NEAR": 3}, report["counts"])
        self.assertEqual([], report["unused_exceptions"])


class RepositoryMixerPolicyContractTests(unittest.TestCase):
    def test_repository_exposes_an_executable_mixer_gate(self):
        gate = ROOT / "parity" / "mixer-verify.sh"
        self.assertTrue(gate.is_file())
        source = gate.read_text()
        for required in (
            "mixer-manifest.tsv",
            "mixer-exceptions.json",
            "batch-golden.mjs",
            "RenderDslBatchFromCommandLine",
            "--manifest",
            "--exceptions",
        ):
            self.assertIn(required, source)

    def test_repository_mixer_manifest_and_policy_are_exact(self):
        manifest_lines = [
            line.split("\t")
            for line in MIXER_MANIFEST.read_text().splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        ]
        self.assertEqual(len(manifest_lines), 12)
        self.assertTrue(all(len(parts) == 2 for parts in manifest_lines))
        self.assertEqual({parts[0] for parts in manifest_lines}, MIXER_FIXTURES)
        self.assertTrue(all((ROOT / parts[1]).is_file() for parts in manifest_lines))

        policy = json.loads(MIXER_EXCEPTIONS.read_text())
        self.assertEqual(1, policy["schema_version"])
        self.assertEqual(
            {
                "mixer__distortion": {
                    "max_abs_diff": 26,
                    "ssim_min": 0.9999,
                    "max_exceeded_pixels": 11,
                    "max_exceeded_channels": 27,
                    "mechanism": "Sparse bilinear displacement UV tie at Voronoi cell boundary pixels.",
                },
                "mixer__thresholdMix": {
                    "max_abs_diff": 223,
                    "ssim_min": 0.9999,
                    "max_exceeded_pixels": 1,
                    "max_exceeded_channels": 3,
                    "allowed_exceeded_pixels": [[39, 119]],
                    "mechanism": "Step/cutoff threshold boundary tie at exactly one borderline noise luminance pixel.",
                },
            },
            policy["cases"],
        )

    def test_repository_mixer_policy_is_exercised_by_the_real_grader(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            gold = root / "gold"
            cand = root / "cand"
            gold.mkdir()
            cand.mkdir()
            for name in MIXER_FIXTURES:
                changed = None
                if name == "mixer__distortion":
                    changed = [(0, 0, (130, 127, 127, 255))]
                elif name == "mixer__thresholdMix":
                    changed = [(39, 119, (130, 127, 127, 255))]
                write_png(gold / f"{name}.golden.png", (127, 127, 127, 255), size=(256, 256))
                write_png(cand / f"{name}.png", (127, 127, 127, 255), size=(256, 256), changed=changed)

            completed, report = run_compare(
                gold,
                cand,
                root / "report.json",
                "--manifest",
                str(MIXER_MANIFEST),
                "--exceptions",
                str(MIXER_EXCEPTIONS),
            )

        self.assertEqual(0, completed.returncode, completed.stderr)
        self.assertIsNotNone(report)
        assert report is not None
        self.assertEqual({"PASS": 10, "ALLOWED_NEAR": 2}, report["counts"])
        self.assertEqual([], report["unused_exceptions"])


class RepositoryPointsPolicyContractTests(unittest.TestCase):
    def test_repository_exposes_an_executable_points_gate(self):
        gate = ROOT / "parity" / "points-verify.sh"
        self.assertTrue(gate.is_file())
        source = gate.read_text()
        for required in (
            "points-manifest.tsv",
            "points-exceptions.json",
            "batch-golden.mjs",
            "RenderDslBatchFromCommandLine",
            "--frames 60",
            "-nmFrames 60",
            "--manifest",
            "--exceptions",
        ):
            self.assertIn(required, source)

    def test_repository_points_manifest_and_policy_are_exact(self):
        manifest_lines = [
            line.split("\t")
            for line in POINTS_MANIFEST.read_text().splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        ]
        self.assertEqual(len(manifest_lines), 10)
        self.assertTrue(all(len(parts) == 2 for parts in manifest_lines))
        self.assertEqual({parts[0] for parts in manifest_lines}, POINTS_FIXTURES)
        self.assertTrue(all((ROOT / parts[1]).is_file() for parts in manifest_lines))

        policy = json.loads(POINTS_EXCEPTIONS.read_text())
        self.assertEqual(1, policy["schema_version"])
        self.assertEqual(
            {
                "points__buddhabrot": {
                    "max_abs_diff": 73,
                    "max_mean_abs_diff": 0.15,
                    "ssim_min": 0.50,
                    "max_exceeded_pixels": 621,
                    "max_exceeded_channels": 1863,
                    "mechanism": "Transcendental complex orbit trajectory ties in Mandelbrot escape trajectory point scatter.",
                },
                "points__dla": {
                    "max_abs_diff": 2,
                    "ssim_min": 0.50,
                    "max_exceeded_pixels": 1,
                    "max_exceeded_channels": 3,
                    "mechanism": "Single-pixel boundary collision rounding tie in diffusion-limited aggregation lattice.",
                },
                "points__flock": {
                    "max_abs_diff": 253,
                    "max_mean_abs_diff": 41.0,
                    "ssim_min": 0.50,
                    "max_exceeded_pixels": 45000,
                    "max_exceeded_channels": 135000,
                    "mechanism": "Boids flocking spatial grid-cell neighbor partition sensitivity; particles form identical flock density (mean 101.4 vs 96.7) with chaotic individual agent trajectories.",
                },
                "points__flow": {
                    "max_abs_diff": 105,
                    "max_mean_abs_diff": 0.002,
                    "ssim_min": 0.50,
                    "max_exceeded_pixels": 3,
                    "max_exceeded_channels": 9,
                    "mechanism": "Sparse vector field bilinear advection boundary tie at 3 particles.",
                },
                "points__hydraulic": {
                    "max_abs_diff": 186,
                    "max_mean_abs_diff": 0.04,
                    "ssim_min": 0.50,
                    "max_exceeded_pixels": 115,
                    "max_exceeded_channels": 345,
                    "mechanism": "Hydraulic erosion droplet trajectory float32 integration tie.",
                },
                "points__lenia": {
                    "max_abs_diff": 253,
                    "max_mean_abs_diff": 15.0,
                    "ssim_min": 0.50,
                    "max_exceeded_pixels": 14000,
                    "max_exceeded_channels": 42000,
                    "mechanism": "Particle Lenia continuous CA convolution energy gradient descent sensitivity; macro-structure and mean density match (mean 32.6 vs 31.3).",
                },
                "points__life": {
                    "max_abs_diff": 249,
                    "max_mean_abs_diff": 0.85,
                    "ssim_min": 0.50,
                    "max_exceeded_pixels": 1424,
                    "max_exceeded_channels": 4272,
                    "mechanism": "Conway continuous particle life neighborhood count quantization ties.",
                },
                "points__physarum": {
                    "max_abs_diff": 252,
                    "max_mean_abs_diff": 36.0,
                    "ssim_min": 0.50,
                    "max_exceeded_pixels": 39000,
                    "max_exceeded_channels": 117000,
                    "mechanism": "Slime mold agent sensor steering positive feedback sensitivity; identical slime trail network convergence and mean brightness (mean 89.0 vs 87.7).",
                },
            },
            policy["cases"],
        )

    def test_repository_points_policy_is_exercised_by_the_real_grader(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            gold = root / "gold"
            cand = root / "cand"
            gold.mkdir()
            cand.mkdir()
            for name in POINTS_FIXTURES:
                # attractor/physical are byte-exact strict PASSes; the other eight
                # carry a single mad=2 pixel so every exception is exercised once
                # (above the tol-1 PASS bound, inside each measured policy).
                changed = [(0, 0, (129, 127, 127, 255))] if name in POINTS_EXCEPTION_CASES else None
                write_png(gold / f"{name}.golden.png", (127, 127, 127, 255), size=(256, 256))
                write_png(cand / f"{name}.png", (127, 127, 127, 255), size=(256, 256), changed=changed)

            completed, report = run_compare(
                gold,
                cand,
                root / "report.json",
                "--ssim-min",
                "0.50",
                "--manifest",
                str(POINTS_MANIFEST),
                "--exceptions",
                str(POINTS_EXCEPTIONS),
            )

        self.assertEqual(0, completed.returncode, completed.stderr)
        self.assertIsNotNone(report)
        assert report is not None
        self.assertEqual({"PASS": 2, "ALLOWED_NEAR": 8}, report["counts"])
        self.assertEqual([], report["unused_exceptions"])


class RepositoryFilterPolicyContractTests(unittest.TestCase):
    def test_repository_exposes_an_executable_filter_gate(self):
        gate = ROOT / "parity" / "filter-verify.sh"
        self.assertTrue(gate.is_file())
        source = gate.read_text()
        for required in (
            "filter-manifest.tsv",
            "filter-exceptions.json",
            "batch-golden.mjs",
            "RenderDslBatchFromCommandLine",
            "--manifest",
            "--exceptions",
        ):
            self.assertIn(required, source)

    def test_repository_filter_manifest_and_policy_are_exact(self):
        manifest_lines = [
            line.split("\t")
            for line in FILTER_MANIFEST.read_text().splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        ]
        self.assertEqual(len(manifest_lines), 50)
        self.assertTrue(all(len(parts) == 2 for parts in manifest_lines))
        self.assertEqual({parts[0] for parts in manifest_lines}, FILTER_FIXTURES)
        self.assertTrue(all((ROOT / parts[1]).is_file() for parts in manifest_lines))

        policy = json.loads(FILTER_EXCEPTIONS.read_text())
        self.assertEqual(1, policy["schema_version"])
        self.assertEqual(set(policy["cases"]), FILTER_EXCEPTION_CASES)
        self.assertEqual(
            {
                "filter__convolutionFeedback": {
                    "max_abs_diff": 8,
                    "max_mean_abs_diff": 0.02,
                    "ssim_min": 0.9999,
                    "max_exceeded_pixels": 770,
                    "max_exceeded_channels": 776,
                    "mechanism": "Iterative kernel convolution feedback accumulation; float32 accumulation drift on sparse high-gradient edges (770 of 65536 pixels, 1.2%).",
                },
                "filter__crt": {
                    "max_abs_diff": 24,
                    "max_mean_abs_diff": 0.03,
                    "ssim_min": 0.9999,
                    "max_exceeded_pixels": 812,
                    "max_exceeded_channels": 991,
                    "mechanism": "Scanline/phosphor-mask color math boundary ties at beam-intensity transitions (812 sparse pixels along mask rows).",
                },
                "filter__degauss": {
                    "max_abs_diff": 8,
                    "ssim_min": 0.9999,
                    "max_exceeded_pixels": 175,
                    "max_exceeded_channels": 175,
                    "mechanism": "Barrel-warp bilinear resample UV boundary ties at high-curvature pixels (175 single-channel flips).",
                },
                "filter__lensWarp": {
                    "max_abs_diff": 3,
                    "ssim_min": 0.9999,
                    "max_exceeded_pixels": 1,
                    "max_exceeded_channels": 3,
                    "allowed_exceeded_pixels": [[178, 225]],
                    "mechanism": "Lens displacement UV bilinear tie at exactly one high-distortion pixel [178, 225].",
                },
                "filter__octaveWarp": {
                    "max_abs_diff": 17,
                    "max_mean_abs_diff": 0.001,
                    "ssim_min": 0.9999,
                    "max_exceeded_pixels": 16,
                    "max_exceeded_channels": 27,
                    "mechanism": "Octaved domain-warp bilinear resample UV ties at warped-gradient crossing pixels (16 sparse flips).",
                },
                "filter__pinch": {
                    "max_abs_diff": 11,
                    "max_mean_abs_diff": 0.001,
                    "ssim_min": 0.9999,
                    "max_exceeded_pixels": 13,
                    "max_exceeded_channels": 24,
                    "mechanism": "Radial pinch displacement bilinear resample UV ties near the pinch center (13 sparse flips).",
                },
                "filter__polar": {
                    "max_abs_diff": 18,
                    "max_mean_abs_diff": 0.003,
                    "ssim_min": 0.9999,
                    "max_exceeded_pixels": 65,
                    "max_exceeded_channels": 142,
                    "mechanism": "Polar remap bilinear resample ties at angle-wrap and radius boundaries (65 sparse flips).",
                },
                "filter__posterize": {
                    "max_abs_diff": 2,
                    "max_mean_abs_diff": 0.001,
                    "ssim_min": 0.9999,
                    "max_exceeded_pixels": 2,
                    "max_exceeded_channels": 2,
                    "mechanism": "Posterize quantization step boundary tie at two level-crossing pixels.",
                },
                "filter__reindex": {
                    "max_abs_diff": 37,
                    "max_mean_abs_diff": 0.003,
                    "ssim_min": 0.9999,
                    "max_exceeded_pixels": 14,
                    "max_exceeded_channels": 36,
                    "mechanism": "Palette reindex nearest-entry lookup tie at color-distance boundaries (14 sparse flips).",
                },
                "filter__rotate": {
                    "max_abs_diff": 34,
                    "max_mean_abs_diff": 0.02,
                    "ssim_min": 0.9999,
                    "max_exceeded_pixels": 112,
                    "max_exceeded_channels": 290,
                    "mechanism": "Rotation resample bilinear UV ties concentrated at frame corners where the rotated domain leaves bounds (112 flips).",
                },
                "filter__scanlineError": {
                    "max_abs_diff": 205,
                    "max_mean_abs_diff": 0.02,
                    "ssim_min": 0.999,
                    "max_exceeded_pixels": 12,
                    "max_exceeded_channels": 36,
                    "mechanism": "Scanline displacement floor() boundary tie: combined_error lands within 1 ULP of a shift-quantization boundary in 12 scattered rows, displacing the sampled texel by one pixel (all 3 channels).",
                },
            },
            policy["cases"],
        )

    def test_repository_filter_policy_is_exercised_by_the_real_grader(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            gold = root / "gold"
            cand = root / "cand"
            gold.mkdir()
            cand.mkdir()
            for name in FILTER_FIXTURES:
                # 21 strict fixtures stay byte-exact; the four exception cases carry
                # a single mad=2 pixel so every exception is exercised once (above
                # the tol-1 PASS bound, inside each measured policy). lensWarp pins
                # its budget to exact pixel [178, 225].
                if name == "filter__lensWarp":
                    changed = [(178, 225, (129, 127, 127, 255))]
                elif name in FILTER_EXCEPTION_CASES:
                    changed = [(0, 0, (129, 127, 127, 255))]
                else:
                    changed = None
                write_png(gold / f"{name}.golden.png", (127, 127, 127, 255), size=(256, 256))
                write_png(cand / f"{name}.png", (127, 127, 127, 255), size=(256, 256), changed=changed)

            completed, report = run_compare(
                gold,
                cand,
                root / "report.json",
                "--manifest",
                str(FILTER_MANIFEST),
                "--exceptions",
                str(FILTER_EXCEPTIONS),
            )

        self.assertEqual(0, completed.returncode, completed.stderr)
        self.assertIsNotNone(report)
        assert report is not None
        self.assertEqual({"PASS": 39, "ALLOWED_NEAR": 11}, report["counts"])
        self.assertEqual([], report["unused_exceptions"])


if __name__ == "__main__":
    unittest.main()
