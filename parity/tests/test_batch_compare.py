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


if __name__ == "__main__":
    unittest.main()
