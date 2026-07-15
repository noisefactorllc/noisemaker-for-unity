# Task 9 Report: Fail-Closed Comparator and Bounded Exceptions

## Status

Complete. The comparator now accepts only `PASS` and fully bounded
`ALLOWED_NEAR` results, rejects empty or incomplete comparisons, validates
exception documents before comparing, and preserves raw byte-space metrics and
the existing global SSIM calculation.

The starting detached worktree contained the Task 9 subprocess test file as
untracked test-first work and no comparator implementation changes. I corrected
its non-object-root fixture, added a nonnumeric-bound case, and captured the
final RED result before changing production code.

## RED evidence

Command:

```bash
python3 -m unittest discover -s parity/tests -p 'test_*.py' -v
```

Saved output:

```text
/private/tmp/noisemaker-task9/comparator-red.log
```

Result: exit 1; 17 named tests ran, with 44 failures and only the existing
within-tolerance behavior passing. The failures demonstrated all intended RED
causes: `--exceptions` was unknown, `NEAR`, missing, mismatched, and empty runs
returned success, configuration error text was absent, and raw exceeded metrics
were not reported.

## Implementation

- `parity/batch-compare.py`
  - Added strict schema-version-1 exception parsing and validation.
  - Rejects malformed JSON, wrong root/case shapes, missing or unknown keys,
    unsupported/bool versions, nonfinite/bool/non-numeric bounds, invalid ranges,
    noninteger/negative counts, invalid or duplicate coordinates, SSIM floors
    below the global threshold, and exception names outside the compared union.
  - Keeps the existing `uint8 -> int16 -> abs` byte delta calculation and the
    existing RGB-luminance `global_ssim` implementation unchanged.
  - Reports unrounded maximum/mean byte deltas, SSIM, exceeded pixel/channel
    counts, and row-major top-left coordinates for same-size non-passing pairs.
  - Promotes only `NEAR` results whose four numeric bounds and optional exact
    coordinate set all match; `FAIL` and structural errors cannot be allowlisted.
  - Reports passing allowlisted cases in `unused_exceptions` and exits 0 only for
    a nonempty result set containing only `PASS` and `ALLOWED_NEAR`.
- `parity/tests/test_batch_compare.py`
  - Added all 17 required subprocess-level CLI contract tests using temporary
    directories and real RGBA PNG files.
- `parity/programs/v104/exceptions.json`
  - Added the approved exact budgets for `craquelure`,
    `mandala_large_format`, `strokes_smudge`, and `strokes_sumi_e`.
- `parity/programs/exceptions.json`
  - Added the approved exact budgets for `parallax` and `refract_mirror`.

## GREEN verification

```bash
python3 -m unittest discover -s parity/tests -p 'test_*.py' -v
```

Result: exit 0; 17/17 tests passed. Saved output:
`/private/tmp/noisemaker-task9/comparator-green.log`.

```bash
python3 -m py_compile parity/batch-compare.py parity/tests/test_batch_compare.py
```

Result: exit 0 with no output. Saved output:
`/private/tmp/noisemaker-task9/py-compile.log`.

```bash
python3 parity/batch-compare.py \
  /private/tmp/noisemaker-task8/v104/golden \
  /private/tmp/noisemaker-task8/v104/candidate-batch-final \
  --tolerance 1 --ssim-min 0.9999
```

Result: expected exit 1; 68 results with 64 `PASS` and 4 `NEAR`. Saved output:
`/private/tmp/noisemaker-task9/v104-unallowlisted.log`.

```bash
python3 parity/batch-compare.py \
  /private/tmp/noisemaker-task8/v104/golden \
  /private/tmp/noisemaker-task8/v104/candidate-batch-final \
  --tolerance 1 --ssim-min 0.9999 \
  --exceptions parity/programs/v104/exceptions.json
```

Result: exit 0; 68 results with 64 `PASS` and 4 `ALLOWED_NEAR`. Saved output:
`/private/tmp/noisemaker-task9/v104-allowlisted.log`.

```bash
python3 parity/batch-compare.py \
  /private/tmp/noisemaker-task8/original/golden \
  /private/tmp/noisemaker-task8/original/candidate-batch-final \
  --tolerance 1 --ssim-min 0.9999 \
  --exceptions parity/programs/exceptions.json
```

Result: exit 0; 20 results with 18 `PASS` and 2 `ALLOWED_NEAR`. Saved output:
`/private/tmp/noisemaker-task9/original-allowlisted.log`.

## Self-review and concerns

- `git diff --check` passed.
- Both repository exception documents passed `python3 -m json.tool`.
- The worktree diff is limited to the four Task 9 deliverable paths plus this
  requested report; no Task 10+ files were touched.
- The six exceptions are intentionally exact corpus debt, not blanket approval:
  any worse maximum, SSIM, exceeded count, or coordinate set remains a failure.
- No implementation concern remains. The only retained concern is the already
  approved backend variance represented by those six narrowly bounded entries.
