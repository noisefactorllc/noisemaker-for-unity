#!/usr/bin/env python3
"""batch-compare.py — compare every golden against its candidate and classify.

Usage: python3 batch-compare.py <goldDir> <candDir> [--out report.json]
  goldDir holds <name>.golden.png ; candDir holds <name>.png
  Classifies each: PASS (within the global tolerance and SSIM threshold),
                   ALLOWED_NEAR (NEAR and within an explicit exception),
                   NEAR (SSIM passes but byte tolerance does not),
                   FAIL (SSIM fails), or a missing/size error.
Prints measured numbers per effect and a summary. Never fabricates.
"""
import argparse
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image


REPO_ROOT = Path(__file__).resolve().parents[1]
REQUIRED_EXCEPTION_FIELDS = {
    "max_abs_diff",
    "ssim_min",
    "max_exceeded_pixels",
    "max_exceeded_channels",
}
OPTIONAL_EXCEPTION_FIELDS = {
    "allowed_exceeded_pixels",
    "max_mean_abs_diff",
    "mechanism",
}


def load_rgba(path):
    return np.asarray(Image.open(path).convert("RGBA"), dtype=np.uint8)


def global_ssim(a, b):
    a = a.astype(np.float32) / 255.0
    b = b.astype(np.float32) / 255.0
    ya = a[..., :3].mean(axis=2)
    yb = b[..., :3].mean(axis=2)
    mu_a, mu_b = ya.mean(), yb.mean()
    va, vb = ya.var(), yb.var()
    cov = ((ya - mu_a) * (yb - mu_b)).mean()
    c1 = (0.01) ** 2
    c2 = (0.03) ** 2
    return float(((2 * mu_a * mu_b + c1) * (2 * cov + c2)) /
                 ((mu_a ** 2 + mu_b ** 2 + c1) * (va + vb + c2)))


def load_manifest(path):
    """Return ordered fixture names; reject malformed or duplicate entries."""

    def invalid(message):
        raise ValueError(f"invalid fixture manifest: {message}")

    try:
        lines = path.read_text().splitlines()
    except (OSError, UnicodeError) as exc:
        invalid(str(exc))

    names = []
    paths = set()
    for line_number, raw in enumerate(lines, start=1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) != 2:
            invalid(f"line {line_number} must be <name><TAB><dslPath>")
        name, dsl_path = (part.strip() for part in parts)
        if not name or not dsl_path:
            invalid(f"line {line_number} must contain a name and DSL path")
        if name in names:
            invalid(f"duplicate fixture name: {name}")
        if dsl_path in paths:
            invalid(f"duplicate fixture path: {dsl_path}")
        resolved_dsl = Path(dsl_path)
        if not resolved_dsl.is_absolute():
            resolved_dsl = REPO_ROOT / resolved_dsl
        if not resolved_dsl.is_file():
            invalid(f"fixture DSL does not exist: {dsl_path}")
        names.append(name)
        paths.add(dsl_path)

    if not names:
        invalid("must contain at least one fixture")
    return names


def validate_fixture_set(expected_names, gold_names, cand_names):
    """Reject any difference between a manifest and either image directory."""
    expected = set(expected_names)
    problems = []
    for label, actual in (("golden", gold_names), ("candidate", cand_names)):
        missing = sorted(expected - actual)
        extra = sorted(actual - expected)
        if missing:
            problems.append(f"missing {label} fixtures: {', '.join(missing)}")
        if extra:
            problems.append(f"unexpected {label} fixtures: {', '.join(extra)}")
    if problems:
        raise ValueError("fixture set does not match manifest: " + "; ".join(problems))


def load_exceptions(path, compared_names, global_ssim_min):
    """Return dict[str, dict]; raise ValueError for every schema/config error."""

    def invalid(message):
        raise ValueError(f"invalid exceptions document: {message}")

    try:
        document = json.loads(path.read_text())
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        invalid(str(exc))

    if not isinstance(document, dict):
        invalid("root must be an object")
    if set(document) != {"schema_version", "cases"}:
        invalid("root keys must be exactly schema_version and cases")
    if type(document["schema_version"]) is not int or document["schema_version"] != 1:
        invalid("schema_version must be integer 1")

    cases = document["cases"]
    if not isinstance(cases, dict):
        invalid("cases must be an object")

    allowed_fields = REQUIRED_EXCEPTION_FIELDS | OPTIONAL_EXCEPTION_FIELDS
    validated = {}
    for name, bounds in cases.items():
        if not isinstance(name, str) or not name:
            invalid("case names must be nonempty strings")
        if not isinstance(bounds, dict):
            invalid(f"case {name!r} must be an object")

        fields = set(bounds)
        missing = REQUIRED_EXCEPTION_FIELDS - fields
        unknown = fields - allowed_fields
        if missing:
            invalid(f"case {name!r} is missing fields: {', '.join(sorted(missing))}")
        if unknown:
            invalid(f"case {name!r} has unknown fields: {', '.join(sorted(unknown))}")

        numeric_fields = ["max_abs_diff", "ssim_min"]
        if "max_mean_abs_diff" in bounds:
            numeric_fields.append("max_mean_abs_diff")
        for field in numeric_fields:
            value = bounds[field]
            if isinstance(value, bool) or not isinstance(value, (int, float)):
                invalid(f"case {name!r} field {field} must be a finite number")
            try:
                finite = math.isfinite(value)
            except OverflowError:
                finite = False
            if not finite:
                invalid(f"case {name!r} field {field} must be a finite number")

        if not 0 <= bounds["max_abs_diff"] <= 255:
            invalid(f"case {name!r} max_abs_diff must be between 0 and 255")
        if "max_mean_abs_diff" in bounds and not 0 <= bounds["max_mean_abs_diff"] <= 255:
            invalid(f"case {name!r} max_mean_abs_diff must be between 0 and 255")
        if not 0 <= bounds["ssim_min"] <= 1:
            invalid(f"case {name!r} ssim_min must be between 0 and 1")
        if bounds["ssim_min"] < global_ssim_min:
            invalid(f"case {name!r} ssim_min is below the global threshold")

        for field in ("max_exceeded_pixels", "max_exceeded_channels"):
            value = bounds[field]
            if type(value) is not int or value < 0:
                invalid(f"case {name!r} field {field} must be a nonnegative integer")

        if "mechanism" in bounds:
            mechanism = bounds["mechanism"]
            if not isinstance(mechanism, str) or not mechanism.strip():
                invalid(f"case {name!r} mechanism must be a nonempty string")

        if "allowed_exceeded_pixels" in bounds:
            coordinates = bounds["allowed_exceeded_pixels"]
            if not isinstance(coordinates, list):
                invalid(f"case {name!r} allowed_exceeded_pixels must be an array")
            seen = set()
            for coordinate in coordinates:
                if not isinstance(coordinate, list) or len(coordinate) != 2:
                    invalid(f"case {name!r} coordinates must be [x, y] arrays")
                if any(type(component) is not int or component < 0 for component in coordinate):
                    invalid(f"case {name!r} coordinates must contain nonnegative integers")
                key = tuple(coordinate)
                if key in seen:
                    invalid(f"case {name!r} coordinates must be unique")
                seen.add(key)

        validated[name] = bounds

    unknown_names = sorted(set(validated) - set(compared_names))
    if unknown_names:
        invalid(f"unknown exception case: {unknown_names[0]}")
    return validated


def exceeded_coordinates(byte_diff, tolerance):
    """Return row-major top-left [[x, y], ...] for exceeded pixels."""
    pixel_mask = np.any(byte_diff > tolerance, axis=2)
    return [[int(x), int(y)] for y, x in np.argwhere(pixel_mask)]


def exception_matches(metrics, exception):
    """Return whether every numeric bound and optional coordinate set passes."""
    if metrics["max_abs_diff"] > exception["max_abs_diff"]:
        return False
    if ("max_mean_abs_diff" in exception and
            metrics["mean_abs_diff"] > exception["max_mean_abs_diff"]):
        return False
    if metrics["ssim"] < exception["ssim_min"]:
        return False
    if metrics["exceeded_pixels"] > exception["max_exceeded_pixels"]:
        return False
    if metrics["exceeded_channels"] > exception["max_exceeded_channels"]:
        return False
    if "allowed_exceeded_pixels" in exception:
        actual = {tuple(coordinate) for coordinate in metrics["exceeded_pixel_coordinates"]}
        allowed = {tuple(coordinate) for coordinate in exception["allowed_exceeded_pixels"]}
        if actual != allowed:
            return False
    return True


def formatted_metric(value, digits):
    return "None" if value is None else f"{value:.{digits}f}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("goldDir", type=Path)
    ap.add_argument("candDir", type=Path)
    ap.add_argument("--out", type=Path, default=None)
    ap.add_argument("--tolerance", type=float, default=2.0)
    ap.add_argument("--ssim-min", type=float, default=0.98)
    ap.add_argument("--exceptions", type=Path, default=None)
    ap.add_argument("--manifest", type=Path, default=None)
    args = ap.parse_args()

    goldens = sorted(args.goldDir.glob("*.golden.png"))
    cand_names = {p.name[:-len(".png")] for p in args.candDir.glob("*.png")}
    gold_names = {g.name[:-len(".golden.png")] for g in goldens}
    compared_names = gold_names | cand_names
    manifest_names = None
    if args.manifest:
        try:
            manifest_names = load_manifest(args.manifest)
            validate_fixture_set(manifest_names, gold_names, cand_names)
        except ValueError as exc:
            ap.error(str(exc))
    exceptions = {}
    if args.exceptions:
        try:
            exceptions = load_exceptions(args.exceptions, compared_names, args.ssim_min)
        except ValueError as exc:
            ap.error(str(exc))

    results = []
    for g in goldens:
        name = g.name[:-len(".golden.png")]
        cand = args.candDir / f"{name}.png"
        rec = {"name": name}
        if not cand.exists():
            rec.update(cls="MISSING_CAND", max_abs_diff=None, ssim=None)
            results.append(rec)
            continue
        a = load_rgba(g)
        b = load_rgba(cand)
        if a.shape != b.shape:
            rec.update(cls="SIZE_MISMATCH", gshape=list(a.shape), cshape=list(b.shape),
                       max_abs_diff=None, ssim=None)
            results.append(rec)
            continue
        byte_diff = np.abs(a.astype(np.int16) - b.astype(np.int16))
        pixel_mask = np.any(byte_diff > args.tolerance, axis=2)
        metrics = {
            "max_abs_diff": float(np.max(byte_diff)),
            "mean_abs_diff": float(np.mean(byte_diff)),
            "ssim": global_ssim(a, b),
            "exceeded_pixels": int(np.count_nonzero(pixel_mask)),
            "exceeded_channels": int(np.count_nonzero(byte_diff > args.tolerance)),
            "exceeded_pixel_coordinates": exceeded_coordinates(byte_diff, args.tolerance),
        }
        if metrics["max_abs_diff"] <= args.tolerance and metrics["ssim"] >= args.ssim_min:
            cls = "PASS"
        elif metrics["ssim"] >= args.ssim_min:
            cls = "NEAR"
        else:
            cls = "FAIL"
        if cls == "NEAR" and name in exceptions and exception_matches(metrics, exceptions[name]):
            cls = "ALLOWED_NEAR"
        rec.update(cls=cls, **metrics)
        if cls == "PASS":
            del rec["exceeded_pixel_coordinates"]
        results.append(rec)

    # candidates without goldens
    for cn in sorted(cand_names - gold_names):
        results.append({"name": cn, "cls": "MISSING_GOLD", "max_abs_diff": None, "ssim": None})

    order = {
        "FAIL": 0,
        "SIZE_MISMATCH": 1,
        "MISSING_CAND": 2,
        "MISSING_GOLD": 3,
        "NEAR": 4,
        "ALLOWED_NEAR": 5,
        "PASS": 6,
    }
    results.sort(key=lambda r: (order.get(r["cls"], 9), r["name"]))

    from collections import Counter
    counts = Counter(r["cls"] for r in results)
    classes_by_name = {r["name"]: r["cls"] for r in results}
    unused_exceptions = sorted(
        name for name in exceptions if classes_by_name.get(name) == "PASS"
    )
    for r in results:
        if r["cls"] in ("PASS",):
            continue
        print(
            f"[{r['cls']:>13}] {r['name']:<40} "
            f"mad={formatted_metric(r.get('max_abs_diff'), 3)} "
            f"ssim={formatted_metric(r.get('ssim'), 6)}"
        )
    for name in unused_exceptions:
        print(f"unused exception: {name}")
    print("\n=== SUMMARY ===")
    print(f"total compared: {len(results)}")
    for k in (
        "PASS",
        "ALLOWED_NEAR",
        "NEAR",
        "FAIL",
        "SIZE_MISMATCH",
        "MISSING_CAND",
        "MISSING_GOLD",
    ):
        if counts.get(k):
            print(f"  {k}: {counts[k]}")
    if args.out:
        report = {
            "counts": dict(counts),
            "results": results,
            "unused_exceptions": unused_exceptions,
        }
        args.out.write_text(json.dumps(report, indent=2) + "\n")
        print(f"wrote {args.out}")
    accepted = {"PASS", "ALLOWED_NEAR"}
    accepted_results = results and all(r["cls"] in accepted for r in results)
    no_unused_manifest_exceptions = not (manifest_names and unused_exceptions)
    return 0 if accepted_results and no_unused_manifest_exceptions else 1


if __name__ == "__main__":
    raise SystemExit(main())
