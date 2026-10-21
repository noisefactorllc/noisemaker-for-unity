#!/usr/bin/env python3
# graph-diff.py — structural diff of two normalized Render Graph JSONs.
#
# Compares the C# live-compiler graph (candidate) against the reference export-graph.mjs
# oracle. The C# normalized form is meant to be byte-identical to the reference (see
# docs/GRAPH-JSON-SCHEMA.md); this is the automated check. Exits 0 when they match
# (0 deltas), 1 otherwise, printing each delta.
#
# The top-level `id` (a per-instance random hash) and `source` (the DSL text, identical
# by construction) are ignored by default.
#
# Usage: python3 graph-diff.py <reference.json> <candidate.json> [--name NAME] [--ignore k,k]

import argparse
import json
import sys


def deepcmp(a, b, path, out):
    if type(a) is not type(b):
        out.append(f"{path}: type ref={type(a).__name__} cand={type(b).__name__}")
        return
    if isinstance(a, dict):
        for k in sorted(set(a) | set(b)):
            if k not in a:
                out.append(f"{path}.{k}: only in candidate")
            elif k not in b:
                out.append(f"{path}.{k}: only in reference")
            else:
                deepcmp(a[k], b[k], f"{path}.{k}", out)
    elif isinstance(a, list):
        if len(a) != len(b):
            out.append(f"{path}: length ref={len(a)} cand={len(b)}")
            return
        for i, (x, y) in enumerate(zip(a, b)):
            deepcmp(x, y, f"{path}[{i}]", out)
    elif a != b:
        out.append(f"{path}: ref={a!r} cand={b!r}")


def compare (ref_path, cand_path, name, ignore=frozenset(("id", "source"))):
    """Diff one program pair. Returns None when clean, else the failure message."""
    try:
        ref = json.load(open(ref_path))
    except (OSError, ValueError) as e:
        return f"cannot read reference graph ({e})"
    try:
        cand = json.load(open(cand_path))
    except (OSError, ValueError) as e:
        # Most common cause: the C# compiler failed/skip-ed this program (NM-GRAPH-FAIL),
        # so no candidate graph was written.
        return f"no candidate graph ({e}) — C# compile likely failed"

    out = []
    for k in sorted(set(ref) | set(cand)):
        if k in ignore:
            continue
        if k not in ref:
            out.append(f"{k}: only in candidate")
        elif k not in cand:
            out.append(f"{k}: only in reference")
        else:
            deepcmp(ref[k], cand[k], k, out)

    if out:
        lines = [f"{len(out)} graph delta(s)"]
        lines += [f"   {d}" for d in out[:40]]
        if len(out) > 40:
            lines.append(f"   … +{len(out) - 40} more")
        return "\n".join(lines)
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("reference", nargs="?")
    ap.add_argument("candidate", nargs="?")
    ap.add_argument("--name", default="")
    ap.add_argument("--ignore", default="id,source",
                    help="comma-separated top-level keys to ignore (default: id,source)")
    ap.add_argument("--batch",
                    help="batch mode: TSV rows <reference.json>\\t<candidate.json>\\t<name>")
    ap.add_argument("--results",
                    help="with --batch: write per-program results as name\\tSTATUS\\tmsg")
    args = ap.parse_args()

    ignore = frozenset(x for x in args.ignore.split(",") if x)

    if args.batch:
        rows = [l.split("\t") for l in open(args.batch).read().splitlines() if l.strip()]
        results = []
        bad = 0
        for ref_path, cand_path, name in rows:
            msg = compare(ref_path, cand_path, name, ignore)
            status = "PASS" if msg is None else ("MISSING" if "no candidate graph" in msg or "cannot read" in msg else "FAIL")
            if msg is not None:
                bad += 1
                print(f"GRAPH FAIL {name}: {msg.replace(chr(10), ' | ')[:300]}")
            results.append((name, status, msg or ""))
        if args.results:
            with open(args.results, "w") as f:
                for name, status, msg in results:
                    f.write(f"{name}\t{status}\t{msg.replace(chr(10), ' | ')}\n")
        print(f"graph parity: {len(rows) - bad} graph-clean, {bad} FAIL/missing, of {len(rows)} programs")
        sys.exit(1 if bad else 0)

    name = args.name or args.candidate
    msg = compare(args.reference, args.candidate, name, ignore)
    if msg is not None:
        print(f"[FAIL] {name}: {msg}")
        sys.exit(1)
    print(f"[PASS] {name}: graph byte-clean (0 deltas)")
    sys.exit(0)


if __name__ == "__main__":
    main()
