# Parity Gate and Fractional Speed Fixes

**Date:** 2026-07-15

**Status:** Approved

**Scope:** Close the two important findings from the final v1.0.104 sync review before integrating the detached commit into local `main`.

## Context

The v1.0.104 sync is functionally complete, but final review found two gaps in its evidence:

1. `parity/batch-compare.py` labels out-of-tolerance results `NEAR`, `FAIL`, or missing/mismatched but always exits zero. The printed report is useful to a person, but the command cannot serve as an automated gate.
2. Mandala and Sacred Geometry convert `speed` to an HLSL integer before applying `floor`. The reference WGSL/GLSL applies `floor` directly to the floating-point uniform. Although the DSL metadata calls this an `int` parameter, both compilers clamp numeric inputs without rounding them, so negative fractional values have observably different semantics (`floor(-1.5) == -2`, while integer truncation produces `-1`).

This design makes the comparison command fail closed, records narrowly bounded known raster exceptions, and adds focused pixel cases for the overlooked speed domain.

## Goals

- Make batch pixel comparison return nonzero for every unapproved divergence.
- Keep known backend-specific raster differences explicit, local, and bounded by measured evidence.
- Match the reference's floating-point `floor(speed)` behavior in both animated generators.
- Prove the speed fix with negative-fractional reference-vs-Unity pixel cases and graph parity.
- Re-run the full v1.0.104, tiled, original, graph, build, and clean Unity import gates before integration.

## Non-goals

- Changing DSL validation or rounding all parameters whose metadata type is `int`.
- Broadly permitting `NEAR` results or weakening the global comparison threshold.
- Eliminating already-understood WebGL2/Unity raster differences in unrelated effects.
- Creating a branch, pushing changes, or opening a pull request.

## Shader semantics

Change the two Mandala speed calculations and the Sacred Geometry speed helper from:

```hlsl
floor((float)(int)speed)
```

to:

```hlsl
floor(speed)
```

This is deliberately narrow. Casts for true selector or enum controls remain unchanged. Both DSL compilers already agree that a numeric argument is clamped to the definition's range but is not rounded according to its metadata type, so the shader must preserve the resulting float until `floor` is applied.

Add two v1.0.104 corpus programs, one for Mandala and one for Sacred Geometry, each setting `speed: -1.5` and enabling an animation branch whose output depends on the floored speed at the fixed parity time. Add both programs to `parity/programs/v104/manifest.tsv`. Their normalized reference and C# graphs must match, and their reference/Unity images must meet the same pixel gate as the rest of the corpus.

## Fail-closed batch comparison

### Command interface

Add one optional argument:

```text
--exceptions <path-to-json>
```

Without `--exceptions`, only `PASS` results produce an overall successful exit. `NEAR`, `FAIL`, `SIZE_MISMATCH`, `MISSING_CAND`, and `MISSING_GOLD` all produce exit code 1. An empty comparison also produces exit code 1 so a missing or misdirected corpus cannot look successful. Invalid arguments or an invalid exceptions document produce argparse/configuration failure, which is also nonzero.

With `--exceptions`, a same-size result that would otherwise be `NEAR` may become `ALLOWED_NEAR` only when the named case exists in the file and every declared bound is satisfied. A `FAIL` result is not eligible: its SSIM must still satisfy the command's global `--ssim-min`. Missing files, size mismatches, and empty corpora can never be approved by an exception.

The process exits zero only when at least one result exists and every result is either `PASS` or `ALLOWED_NEAR`.

### Measured fields

For each same-size image pair, retain the existing `max_abs_diff`, `mean_abs_diff`, and RGB luminance `ssim` fields. Also report:

- `exceeded_pixels`: number of pixels where any RGBA channel's absolute byte delta is greater than the global `--tolerance`.
- `exceeded_channels`: number of individual RGBA channels whose absolute byte delta is greater than the global tolerance.
- `exceeded_pixel_coordinates`: top-left-origin `[x, y]` coordinates for those pixels, emitted for non-passing cases so exception failures are diagnosable.

All approval checks use unrounded metrics. Rounding is presentation-only.

### Exception schema

The JSON document is versioned and keyed by the case name used by the batch comparator:

```json
{
  "schema_version": 1,
  "cases": {
    "example_case": {
      "max_abs_diff": 2,
      "ssim_min": 0.99999,
      "max_exceeded_pixels": 4,
      "max_exceeded_channels": 4,
      "allowed_exceeded_pixels": [[10, 20], [11, 20]]
    }
  }
}
```

Every case entry must define the four numeric bounds, and its `ssim_min` must be greater than or equal to the command's global `--ssim-min`. `allowed_exceeded_pixels` is optional; when present, it must contain unique integer coordinates and the actual exceeded-coordinate set must exactly equal it regardless of JSON array order. A fully passing pair bypasses exception evaluation, so an improvement to zero exceeded pixels still passes. Unknown case names are rejected as configuration errors, preventing misspelled or cross-corpus exception files from silently doing nothing. Valid but unused entries whose matching pair now passes are reported but do not fail the run.

Two repository-owned files keep unrelated corpora isolated:

- `parity/programs/v104/exceptions.json`
- `parity/programs/exceptions.json`

The initial budgets are derived from the already-recorded 2026-07-15 evidence at tolerance 1. Integer maximums equal the measured values; SSIM floors retain only a sub-millionth representation margin while remaining well above the global threshold:

| Corpus | Case | Max diff | Measured SSIM | SSIM floor | Exceeded pixels | Exceeded channels | Exact exceeded coordinates |
|---|---|---:|---:|---:|---:|---:|---|
| v1.0.104, 127px | `craquelure` | 2 | 0.999993503 | 0.99999 | 9 | 9 | `(46,18)`, `(44,24)`, `(33,49)`, `(62,53)`, `(19,101)`, `(23,105)`, `(19,107)`, `(7,112)`, `(43,125)` |
| v1.0.104, 127px | `mandala_large_format` | 255 | 0.999999464 | 0.999999 | 1 | 3 | `(126,109)` |
| v1.0.104, 127px | `strokes_smudge` | 2 | 1.0 | 0.999999 | 1 | 1 | `(37,23)` |
| v1.0.104, 127px | `strokes_sumi_e` | 2 | 1.0 | 0.999999 | 4 | 4 | `(107,1)`, `(48,35)`, `(48,75)`, `(82,124)` |
| Original, 256px | `parallax` | 26 | 0.999998093 | 0.999998 | 3 | 8 | `(148,39)`, `(117,69)`, `(61,197)` |
| Original, 256px | `refract_mirror` | 19 | 0.999998808 | 0.999998 | 7 | 18 | `(7,44)`, `(252,49)`, `(196,50)`, `(172,102)`, `(180,148)`, `(190,201)`, `(146,250)` |

The JSON values use the table's explicit SSIM floors, measured integer maximums, and exact coordinates. Approval compares the unrounded calculated SSIM against the stored floor. The existing Mandala outlier is deliberately localized to its single edge pixel rather than approved through a blanket max-difference allowance.

## Test strategy

Implementation follows test-driven development.

### Comparator unit and CLI tests

Create focused Python tests with temporary RGBA PNGs and subprocess execution of the real CLI. First observe them fail against the current script. Cover:

- A one-byte delta that is within tolerance: `PASS`, exit 0.
- A high-SSIM delta beyond tolerance with no exceptions file: `NEAR`, exit 1.
- The same delta inside every named budget: `ALLOWED_NEAR`, exit 0.
- A delta exceeding each type of bound, including a coordinate mismatch: remains `NEAR`, exit 1.
- Low SSIM: `FAIL`, exit 1 and cannot be allowlisted.
- Missing candidate, extra candidate/missing golden, size mismatch, and empty input: exit 1.
- Invalid schema, unknown case key, and missing required bounds: configuration failure.
- Report JSON counts and per-case metrics include `ALLOWED_NEAR` and exceeded counts consistently.

### Fractional-speed parity tests

Add the two DSL cases and generate their reference goldens before the shader change. Render them with the old HLSL and record the expected RED divergence. Then apply the shader fix, render again, and require the focused batch gate plus graph-diff to pass. This proves the test fails for the reviewed bug rather than merely exercising a line of code.

### Regression gates

After focused tests pass:

1. Run all comparator tests and Python syntax checks.
2. Run the definition converter in check mode and the .NET compiler build/tests.
3. Run graph parity for the complete self-test, DSL corpus, and targeted variants; the DSL corpus grows by two cases.
4. Render and compare the complete updated v1.0.104 corpus using its exception file.
5. Render and compare the nonzero-tile corpus; it must remain strict with no exceptions.
6. Compare the original 20-case corpus using its separate exception file.
7. Perform a clean Unity import/compile and inspect logs for shader failures or new severity findings.
8. Request a fresh read-only code review of the detached final commit.

## Documentation and integration

Update `parity/README.md` so examples describe the fail-closed exit contract, the exception-file workflow, the two new fractional-speed cases, and current corpus/graph totals. Record the final commands and measured outcomes in the existing v1.0.104 verification evidence.

After all verification and review findings are clear, commit on the detached worktree, fast-forward `/Users/alex/source/noisemaker-unity` local `main` directly to the verified detached commit, verify `main`, and remove the detached worktree. No feature branch, remote push, or pull request is created.

## Acceptance criteria

- `batch-compare.py` without an exception file returns nonzero for every non-`PASS` result and for an empty run.
- Only explicitly named, fully bounded `NEAR` cases can yield `ALLOWED_NEAR` and a successful overall result.
- The two corpus exception files reproduce exactly the documented current raster debt and cannot approve missing, mismatched, low-SSIM, or newly located divergences.
- Mandala and Sacred Geometry use reference-equivalent `floor(speed)` semantics.
- Both negative-fractional speed tests are demonstrated RED before the code change and green afterward.
- Focused and full regression gates pass, and a fresh reviewer reports no important issues.
- The verified work lands only as a local fast-forward on `main`; no branch or PR remains.
