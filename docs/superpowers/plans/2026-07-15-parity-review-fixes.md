# Parity Review Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the pixel comparator a fail-closed automated gate and restore reference-equivalent negative-fractional animation speed semantics for Mandala and Sacred Geometry.

**Architecture:** Keep pixel measurement in the existing Python CLI, adding a versioned per-case exception layer that can promote only globally high-SSIM `NEAR` results. Preserve floating-point DSL numeric values through HLSL and apply `floor` at the same point as the reference shaders. Prove both changes with subprocess-level comparator tests and reference-vs-Unity RED/GREEN pixel cases before running the complete regression matrix.

**Tech Stack:** Python 3 with stdlib `unittest`, NumPy, and Pillow; Noisemaker DSL and Node 22 reference renderer; Unity 6000.3.16f1 with HLSL/Metal; .NET 8 graph dumper; Git in a detached local worktree.

## Global Constraints

- Work only in the detached worktree `/Users/alex/source/.codex-worktrees/noisemaker-for-unity-v104`; do not create a branch.
- Treat `/Users/alex/source/noisemaker` at `755071128ba6112753b9e976dc0ebbb8e55449b5` as authoritative and read-only.
- Work local only: no push, pull request, remote mutation, or surviving feature branch.
- Preserve exact `uint8` byte-difference measurement and the existing RGB-luminance global SSIM formula.
- Only a same-size case that passes global `--ssim-min` and is otherwise `NEAR` may be allowlisted. `FAIL`, missing, mismatched, and empty inputs always fail.
- Exception budgets are case-specific and must check maximum difference, SSIM floor, exceeded-pixel count, exceeded-channel count, and exact coordinates where declared.
- Casts for actual selectors/enums remain; only the three reviewed speed-floor expressions change.
- Generated PNGs, graphs, logs, manifests containing absolute paths, and Unity `Library`/`Temp` output remain outside git.
- Use `/tmp/nmhlsl-unity-v104.HKAHvK` for Unity verification; never modify `/Users/alex/nmhlsl-unity`.
- No completion claim before focused RED/GREEN evidence, all full gates, a fresh code review, and verification of the fast-forwarded local `main`.

## File Map

- `parity/batch-compare.py`: CLI argument parsing, image metrics, exception validation, classification, reporting, and process exit.
- `parity/tests/test_batch_compare.py`: subprocess-level contract tests for real PNG directories and exception documents.
- `parity/programs/exceptions.json`: bounded original-corpus raster debt.
- `parity/programs/v104/exceptions.json`: bounded v1.0.104 raster debt.
- `parity/programs/v104/mandala_negative_fractional_speed.dsl`: focused negative-fractional Mandala animation case.
- `parity/programs/v104/sacred_geometry_negative_fractional_speed.dsl`: focused negative-fractional Sacred Geometry animation case.
- `parity/programs/v104/manifest.tsv`: names both new pixel/graph cases.
- `unity/com.noisemaker.hlsl/Shaders/Effects/synth/Mandala.hlsl`: two direct `floor(speed)` calculations.
- `unity/com.noisemaker.hlsl/Shaders/Effects/synth/SacredGeometry.hlsl`: direct `floor(speed)` helper.
- `parity/README.md`: fail-closed/exception workflow and updated 70-case/304-case totals.
- `.superpowers/sdd/task-11-report.md`: commands and final measured evidence for these review fixes.
- `.superpowers/sdd/progress.md`: final Task 9 status.
- `docs/superpowers/specs/2026-07-15-parity-gate-and-fractional-speed-fixes-design.md`: approved-to-implemented status transition after verification.

---

### Task 9: Fail-Closed Comparator and Bounded Exceptions

**Files:**

- Create: `parity/tests/test_batch_compare.py`
- Create: `parity/programs/exceptions.json`
- Create: `parity/programs/v104/exceptions.json`
- Modify: `parity/batch-compare.py`

**Interfaces:**

- Consumes: golden files named `<case>.golden.png`, candidates named `<case>.png`, global `--tolerance` and `--ssim-min`, and optional `--exceptions PATH`.
- Produces: result classes `PASS`, `ALLOWED_NEAR`, `NEAR`, `FAIL`, `SIZE_MISMATCH`, `MISSING_CAND`, and `MISSING_GOLD`; JSON fields `counts`, `results`, and `unused_exceptions`; exit 0 only for a nonempty all-accepted run.

- [ ] **Step 1: Write subprocess-level comparator contract tests**

Create a `unittest.TestCase` that uses `TemporaryDirectory`, Pillow's `Image.new`, and `subprocess.run`. The shared helper must invoke the real script and read its `--out` JSON:

```python
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
        [sys.executable, str(SCRIPT), str(gold), str(cand),
         "--out", str(report), "--tolerance", "1", "--ssim-min", "0.98", *extra],
        text=True, capture_output=True, check=False)
    data = json.loads(report.read_text()) if report.exists() else None
    return completed, data
```

Add named tests for all of these contracts:

```text
test_within_tolerance_passes
test_near_without_exception_fails
test_fully_bounded_near_is_allowed
test_exception_rejects_max_diff_overrun
test_exception_rejects_ssim_floor_overrun
test_exception_rejects_pixel_count_overrun
test_exception_rejects_channel_count_overrun
test_exception_rejects_coordinate_change
test_fail_cannot_be_allowlisted
test_missing_candidate_fails
test_missing_golden_fails
test_size_mismatch_fails
test_empty_directories_fail
test_invalid_exception_documents_are_configuration_errors
test_unknown_exception_case_is_configuration_error
test_passing_allowlisted_case_is_reported_unused
test_report_contains_raw_exceeded_metrics_and_counts
```

For `NEAR`, use identical 16×16 `(127,127,127,255)` images except candidate pixel `(3,4)` becomes `(129,127,127,255)`. For `FAIL`, compare all-black RGB against all-white RGB. Exercise invalid documents for malformed JSON, unsupported `schema_version`, missing/extra keys, bool-as-number fields, out-of-range values, duplicate coordinates, and `ssim_min` below the global threshold.

- [ ] **Step 2: Run the new suite and capture the RED result**

Run:

```bash
python3 -m unittest discover -s parity/tests -p 'test_*.py' -v
```

Expected before implementation: multiple failures because `--exceptions` is unknown, `NEAR` exits 0, missing/mismatched/empty runs exit 0, and exceeded metrics are absent. Save the command output under `/private/tmp/noisemaker-task9/comparator-red.log`.

- [ ] **Step 3: Add strict exception parsing and validation**

Add `--exceptions` and focused helpers with these signatures:

```python
REQUIRED_EXCEPTION_FIELDS = {
    "max_abs_diff", "ssim_min", "max_exceeded_pixels", "max_exceeded_channels"
}
OPTIONAL_EXCEPTION_FIELDS = {"allowed_exceeded_pixels"}

def load_exceptions(path, compared_names, global_ssim_min):
    """Return dict[str, dict]; raise ValueError for every schema/config error."""

def exceeded_coordinates(byte_diff, tolerance):
    """Return row-major top-left [[x, y], ...] for pixels with any RGBA delta > tolerance."""

def exception_matches(metrics, exception):
    """Return True only when every numeric bound and optional exact coordinate set passes."""
```

Validation must require root keys exactly `schema_version` and `cases`, version integer 1, nonempty string case keys, the four required case fields, no unknown fields, finite non-bool numeric bounds, integer nonnegative counts, `0 <= max_abs_diff <= 255`, `0 <= ssim_min <= 1`, exception `ssim_min >= --ssim-min`, and unique nonnegative integer `[x,y]` coordinates. Reject exception case names absent from the union of golden/candidate case names via `argparse.ArgumentParser.error`, yielding exit 2.

- [ ] **Step 4: Calculate exceeded metrics and promote only eligible NEAR results**

Preserve `byte_diff = abs(uint8.astype(int16) - uint8.astype(int16))`. For same-size pairs, calculate raw values and classify in this order:

```python
pixel_mask = np.any(byte_diff > args.tolerance, axis=2)
coords = [[int(x), int(y)] for y, x in np.argwhere(pixel_mask)]
metrics = {
    "max_abs_diff": float(np.max(byte_diff)),
    "mean_abs_diff": float(np.mean(byte_diff)),
    "ssim": global_ssim(a, b),
    "exceeded_pixels": int(np.count_nonzero(pixel_mask)),
    "exceeded_channels": int(np.count_nonzero(byte_diff > args.tolerance)),
    "exceeded_pixel_coordinates": coords,
}

if metrics["max_abs_diff"] <= args.tolerance and metrics["ssim"] >= args.ssim_min:
    cls = "PASS"
elif metrics["ssim"] >= args.ssim_min:
    cls = "NEAR"
else:
    cls = "FAIL"
if cls == "NEAR" and name in exceptions and exception_matches(metrics, exceptions[name]):
    cls = "ALLOWED_NEAR"
```

Keep raw numeric values in JSON. Round only formatted console values. Include exceeded coordinates in non-`PASS` results. Add `ALLOWED_NEAR` to sorting and summary counts. List matching exception names whose results are `PASS` in top-level `unused_exceptions` and print them informationally.

- [ ] **Step 5: Make overall exit status fail closed**

Return 1 when there are no results or any class is outside `{"PASS", "ALLOWED_NEAR"}`; otherwise return 0:

```python
accepted = {"PASS", "ALLOWED_NEAR"}
return 0 if results and all(r["cls"] in accepted for r in results) else 1
```

- [ ] **Step 6: Add the exact repository exception documents**

Create the v1.0.104 file with cases `craquelure`, `mandala_large_format`, `strokes_smudge`, and `strokes_sumi_e`, and the original file with `parallax` and `refract_mirror`. Copy the exact integer budgets, SSIM floors, and coordinate arrays from the approved design spec. The resulting structure must be:

```json
{
  "schema_version": 1,
  "cases": {
    "case_name": {
      "max_abs_diff": 2,
      "ssim_min": 0.99999,
      "max_exceeded_pixels": 1,
      "max_exceeded_channels": 1,
      "allowed_exceeded_pixels": [[37, 23]]
    }
  }
}
```

- [ ] **Step 7: Run unit/syntax tests and reproduce the current corpus debt**

Run:

```bash
python3 -m unittest discover -s parity/tests -p 'test_*.py' -v
python3 -m py_compile parity/batch-compare.py parity/tests/test_batch_compare.py
python3 parity/batch-compare.py /private/tmp/noisemaker-task8/v104/golden /private/tmp/noisemaker-task8/v104/candidate-batch-final --tolerance 1 --ssim-min 0.9999
python3 parity/batch-compare.py /private/tmp/noisemaker-task8/v104/golden /private/tmp/noisemaker-task8/v104/candidate-batch-final --tolerance 1 --ssim-min 0.9999 --exceptions parity/programs/v104/exceptions.json
python3 parity/batch-compare.py /private/tmp/noisemaker-task8/original/golden /private/tmp/noisemaker-task8/original/candidate-batch-final --tolerance 1 --ssim-min 0.9999 --exceptions parity/programs/exceptions.json
```

Expected: tests/syntax pass; the unallowlisted v1.0.104 command exits 1; both explicitly allowlisted commands exit 0 with only `PASS` and `ALLOWED_NEAR`.

- [ ] **Step 8: Commit the comparator unit**

```bash
git add parity/batch-compare.py parity/tests/test_batch_compare.py \
  parity/programs/exceptions.json parity/programs/v104/exceptions.json
git diff --cached --check
git commit -m "fix: make pixel parity gate fail closed"
```

---

### Task 10: Negative-Fractional Speed RED/GREEN Parity

**Files:**

- Create: `parity/programs/v104/mandala_negative_fractional_speed.dsl`
- Create: `parity/programs/v104/sacred_geometry_negative_fractional_speed.dsl`
- Modify: `parity/programs/v104/manifest.tsv`
- Modify: `unity/com.noisemaker.hlsl/Shaders/Effects/synth/Mandala.hlsl`
- Modify: `unity/com.noisemaker.hlsl/Shaders/Effects/synth/SacredGeometry.hlsl`

**Interfaces:**

- Consumes: numeric DSL `speed: -1.5`, normalized time 0.25, reference compiler float uniforms, and Unity `SetFloat` bindings.
- Produces: two deterministic direct-generator graphs/images and reference-equivalent `floor(speed)` shader behavior.

- [ ] **Step 1: Add focused DSL cases before changing HLSL**

Use Mandala's per-layer differential branch and a seven-fold triangle so the `-pi/2` phase difference at time 0.25 cannot be hidden by rotational symmetry. Use Sacred Geometry's whole-domain rotation branch for an independent path:

```text
search synth

mandala(
  scale: 11, rotation: 13, thickness: 0.34, smoothness: 0.03,
  symmetry: 7, shape: triangle, layers: 8, layerSpacing: 1.25,
  twist: 11, shapeGrowth: 0.2, fgColor: #e8ab38, bgColor: #16335f,
  animation: differential, speed: -1.5, pulseDepth: 0.7
)
  .write(o0)

render(o0)
```

```text
search synth

sacredGeometry(
  geometry: starPolygon, scale: 12, starPoints: 7, rotation: -17,
  thickness: 0.3, smoothness: 0.03, fgColor: #4de3b4, bgColor: #35145f,
  animation: rotate, speed: -1.5, pulseDepth: 0.6
)
  .write(o0)

render(o0)
```

Append these manifest rows exactly once:

```text
mandala_negative_fractional_speed\tparity/programs/v104/mandala_negative_fractional_speed.dsl
sacred_geometry_negative_fractional_speed\tparity/programs/v104/sacred_geometry_negative_fractional_speed.dsl
```

- [ ] **Step 2: Generate focused reference outputs and prove the old shader is RED**

Create `/private/tmp/noisemaker-task9/speed/manifest.tsv` by selecting the two new rows. Generate reference graphs/goldens, derive a graph render manifest, and render the unchanged shaders:

```bash
mkdir -p /private/tmp/noisemaker-task9/speed/{golden,candidate-red,candidate-green,graph-cs}
rg 'negative_fractional_speed' parity/programs/v104/manifest.tsv > /private/tmp/noisemaker-task9/speed/manifest.tsv
PATH=/tmp/nm-node.SoOIaC/nodeenv/bin:$PATH NM_REFERENCE_ROOT=/Users/alex/source/noisemaker SHADE_HEADLESS=1 \
  node parity/batch-golden.mjs /private/tmp/noisemaker-task9/speed/manifest.tsv \
  /private/tmp/noisemaker-task9/speed/golden --size 127 --time 0.25 --backend webgl2
awk -F'\t' -v gold=/private/tmp/noisemaker-task9/speed/golden \
  -v out=/private/tmp/noisemaker-task9/speed/candidate-red \
  '{print gold "/" $1 ".graph.json\t" out "/" $1 ".png"}' \
  /private/tmp/noisemaker-task9/speed/manifest.tsv > /private/tmp/noisemaker-task9/speed/render-red.tsv
"/Applications/Unity/Hub/Editor/6000.3.16f1/Unity.app/Contents/MacOS/Unity" \
  -batchmode -quit -projectPath /tmp/nmhlsl-unity-v104.HKAHvK \
  -logFile /private/tmp/noisemaker-task9/speed/unity-red.log \
  -executeMethod Noisemaker.Hlsl.Editor.NMParityRunner.RenderBatchFromCommandLine \
  -nmManifest /private/tmp/noisemaker-task9/speed/render-red.tsv -nmSize 127 -nmTime 0.25
python3 parity/batch-compare.py /private/tmp/noisemaker-task9/speed/golden \
  /private/tmp/noisemaker-task9/speed/candidate-red --tolerance 1 --ssim-min 0.9999 \
  --out /private/tmp/noisemaker-task9/speed/red-report.json
```

Expected: both graphs/goldens and candidates are produced, and the comparator exits 1 with both focused cases outside strict tolerance.

- [ ] **Step 3: Apply the minimal shader semantic fix**

Replace exactly two Mandala occurrences and the Sacred Geometry helper body:

```hlsl
float speedStep = floor(speed);
```

```hlsl
float nmsg_speedStep() { return floor(speed); }
```

Confirm no reviewed expression remains:

```bash
! rg 'floor\(\(float\)\(int\)speed\)' unity/com.noisemaker.hlsl/Shaders/Effects/synth
```

- [ ] **Step 4: Re-render and prove focused pixel GREEN**

Build `render-green.tsv` by replacing the candidate output directory in the RED manifest, rerun the same Unity command, and compare without an exception file:

```bash
sed 's|candidate-red|candidate-green|g' /private/tmp/noisemaker-task9/speed/render-red.tsv > /private/tmp/noisemaker-task9/speed/render-green.tsv
"/Applications/Unity/Hub/Editor/6000.3.16f1/Unity.app/Contents/MacOS/Unity" \
  -batchmode -quit -projectPath /tmp/nmhlsl-unity-v104.HKAHvK \
  -logFile /private/tmp/noisemaker-task9/speed/unity-green.log \
  -executeMethod Noisemaker.Hlsl.Editor.NMParityRunner.RenderBatchFromCommandLine \
  -nmManifest /private/tmp/noisemaker-task9/speed/render-green.tsv -nmSize 127 -nmTime 0.25
python3 parity/batch-compare.py /private/tmp/noisemaker-task9/speed/golden \
  /private/tmp/noisemaker-task9/speed/candidate-green --tolerance 1 --ssim-min 0.9999 \
  --out /private/tmp/noisemaker-task9/speed/green-report.json
```

Expected: exit 0 and both cases classify `PASS`.

- [ ] **Step 5: Prove focused graph parity preserves `speed: -1.5`**

Build graphdump, create a DSL/output manifest from the two focused rows, dump C# graphs, and compare them against the reference `.graph.json` files:

```bash
/tmp/nm-dotnet.FoaV14/dotnet/dotnet build -c Release tools/graphdump
awk -F'\t' -v out=/private/tmp/noisemaker-task9/speed/graph-cs \
  '{print $2 "\t" out "/" $1 ".json"}' /private/tmp/noisemaker-task9/speed/manifest.tsv \
  > /private/tmp/noisemaker-task9/speed/graphdump.tsv
/tmp/nm-dotnet.FoaV14/dotnet/dotnet tools/graphdump/bin/Release/net8.0/graphdump.dll \
  unity/com.noisemaker.hlsl/Effects /private/tmp/noisemaker-task9/speed/graphdump.tsv
for name in mandala_negative_fractional_speed sacred_geometry_negative_fractional_speed; do
  python3 parity/graph-diff.py \
    "/private/tmp/noisemaker-task9/speed/golden/$name.graph.json" \
    "/private/tmp/noisemaker-task9/speed/graph-cs/$name.json" --name "$name"
done
```

Expected: build has 0 warnings/errors, graphdump reports 2 ok/0 fail, and both structural diffs pass.

- [ ] **Step 6: Commit the semantic fix and its regression cases**

```bash
git add parity/programs/v104/manifest.tsv \
  parity/programs/v104/mandala_negative_fractional_speed.dsl \
  parity/programs/v104/sacred_geometry_negative_fractional_speed.dsl \
  unity/com.noisemaker.hlsl/Shaders/Effects/synth/Mandala.hlsl \
  unity/com.noisemaker.hlsl/Shaders/Effects/synth/SacredGeometry.hlsl
git diff --cached --check
git commit -m "fix: preserve fractional animation speed semantics"
```

---

### Task 11: Full Regression Gates and Documentation

**Files:**

- Modify: `parity/README.md`
- Create: `.superpowers/sdd/task-11-report.md`

**Interfaces:**

- Consumes: Task 9 comparator/exception files, Task 10 70-row manifest and shaders, existing disposable Unity project/runtime paths.
- Produces: fresh full pixel reports, 304-case canonical graph evidence, clean Unity/.NET evidence, and repository documentation tied to actual command output.

- [ ] **Step 1: Run static and unit gates**

Run and save outputs under `/private/tmp/noisemaker-task9`:

```bash
python3 -m unittest discover -s parity/tests -p 'test_*.py' -v
python3 -m py_compile parity/batch-compare.py parity/tests/test_batch_compare.py parity/compare.py parity/graph-diff.py
PATH=/tmp/nm-node.SoOIaC/nodeenv/bin:$PATH node --check parity/batch-golden.mjs
PATH=/tmp/nm-node.SoOIaC/nodeenv/bin:$PATH node --check tools/convert-definitions.mjs
/tmp/nm-dotnet.FoaV14/dotnet/dotnet build -c Release tools/graphdump
git diff --check
```

Expected: all tests/syntax checks pass, .NET reports 0 warnings/0 errors, and git diff check is empty.

- [ ] **Step 2: Verify generated definitions remain authoritative**

Run the converter into a temporary output directory and diff that projection against the tracked definitions; require 210 definitions, 0 failures, and no content delta:

```bash
rm -rf /private/tmp/noisemaker-task9/definitions
PATH=/tmp/nm-node.SoOIaC/nodeenv/bin:$PATH \
  NM_REFERENCE_ROOT=/Users/alex/source/noisemaker \
  NM_OUT_DIR=/private/tmp/noisemaker-task9/definitions \
  node tools/convert-definitions.mjs
diff -ru --exclude='*.meta' /private/tmp/noisemaker-task9/definitions \
  unity/com.noisemaker.hlsl/Effects
find /private/tmp/noisemaker-task9/definitions -name '*.json' | wc -l
```

Expected: converter reports 210 written/0 failed, diff exits 0, count is 210.

- [ ] **Step 3: Rebuild the complete 304-case canonical graph gate**

Construct `/private/tmp/noisemaker-task9/graph/cases.tsv` from 207 `--selftest/manifest.tsv` rows, all 90 `parity/programs/**/*.dsl` files (20 original plus 70 v1.0.104), and seven `.superpowers/sdd/task-7-targeted/*.dsl` files. Reject duplicate names and require 304 rows. Export every reference graph with `tools/export-graph.mjs`, dump every C# graph in one graphdump invocation, and run `parity/graph-diff.py` for every pair. Save ref/cs/report files outside git.

Expected: 304 reference exports, graphdump 304 ok/0 fail, and 304 PASS/0 FAIL. Re-run the 20 `parity/corpus/*.dsl` supplemental paths and require the existing behavioral result: 19 structural passes plus the same shared `B5oBsA` rejection in both compilers.

- [ ] **Step 4: Perform a clean Unity import/Metal compile**

Remove only disposable project state, then run Unity batchmode against the worktree package:

```bash
rm -rf /tmp/nmhlsl-unity-v104.HKAHvK/Library /tmp/nmhlsl-unity-v104.HKAHvK/Temp /tmp/nmhlsl-unity-v104.HKAHvK/Logs
"/Applications/Unity/Hub/Editor/6000.3.16f1/Unity.app/Contents/MacOS/Unity" \
  -batchmode -quit -projectPath /tmp/nmhlsl-unity-v104.HKAHvK \
  -logFile /private/tmp/noisemaker-task9/unity-clean.log
```

Require process exit 0, no C# compiler error, no shader compile failure, 0 severity-2-or-higher shader diagnostics, and no new severity-1 diagnostic class/site attributable to the three edited shader expressions.

- [ ] **Step 5: Render and compare the fresh 70-case v1.0.104 corpus**

Generate all goldens/graphs from `parity/programs/v104/manifest.tsv`, derive a Unity render manifest, render in one Unity session at 127×127/time 0.25, and run:

```bash
python3 parity/batch-compare.py /private/tmp/noisemaker-task9/v104/golden \
  /private/tmp/noisemaker-task9/v104/candidate --tolerance 1 --ssim-min 0.9999 \
  --exceptions parity/programs/v104/exceptions.json \
  --out /private/tmp/noisemaker-task9/v104/report.json
```

Expected: 70 images rendered, no missing/failed case, exit 0, the two new speed cases are strict `PASS`, and every other non-`PASS` is one of the four exactly bounded `ALLOWED_NEAR` cases.

- [ ] **Step 6: Re-run strict tiled and bounded original pixel gates**

Regenerate and render the three `tiled-manifest.tsv` cases using tile `(1536,2048)`, full resolution `4096×4096`, render scale 1, size 127, time 0.25; compare without exceptions and require 3 `PASS`, exit 0. Regenerate/render the 20 top-level original programs at 256×256/time 0.25 and compare with `parity/programs/exceptions.json`; require exit 0, with only `parallax` and `refract_mirror` eligible for `ALLOWED_NEAR`.

- [ ] **Step 7: Update documentation from the machine-readable reports**

Update `parity/README.md` to state 70 v1.0.104 programs, 90 `parity/programs/**/*.dsl` cases, and 304 canonical graph cases. Document `--exceptions`, the `PASS`/`ALLOWED_NEAR` exit contract, the two exception-file paths, and strict usage for new corpora. Replace prose pixel distributions with counts read from the fresh JSON reports rather than hand-estimated values.

Create `.superpowers/sdd/task-11-report.md` containing the exact detached commit range, runtime paths, RED and GREEN focused results, unit-test count, 304-case graph result, clean Unity compiler totals/diagnostic classification, 70/3/20 pixel report counts, definition check, and source/original-project cleanliness. Final review and integration results are appended in Task 12, after they exist.

- [ ] **Step 8: Commit verified documentation**

```bash
git add parity/README.md .superpowers/sdd/task-11-report.md
git diff --cached --check
git commit -m "docs: record fail-closed parity verification"
```

---

### Task 12: Fresh Review, Local Main Fast-Forward, and Cleanup

**Files:**

- Modify only if review finds a verified defect: affected source/test/docs files.
- Modify: `.superpowers/sdd/task-11-report.md`
- Modify: `.superpowers/sdd/progress.md`
- Modify: `docs/superpowers/specs/2026-07-15-parity-gate-and-fractional-speed-fixes-design.md`
- No branch, PR, or remote files.

**Interfaces:**

- Consumes: merge base `2ab966e9d7c39e5e2704f345f09ced460dcf7cab`, detached verified HEAD, all Task 11 evidence.
- Produces: clean reviewed local `main` in `/Users/alex/source/noisemaker-for-unity` and removal of the detached worktree.

- [ ] **Step 1: Request a fresh read-only code review**

Use `superpowers:requesting-code-review` with a new reviewer that receives the approved design, this implementation plan, `git diff 2ab966e..HEAD`, and Task 9 evidence. Require review of comparator fail-closed behavior/schema, negative-fractional shader semantics, RED/GREEN test validity, exception budgets, docs/counts, artifacts, and local-only delivery constraints.

- [ ] **Step 2: Resolve every Critical/Important finding test-first**

For each finding, reproduce it with the narrowest test, apply the minimal fix, rerun the focused test plus affected full gate, commit on detached HEAD, and request another fresh review. Stop only when there are no Critical/Important findings.

- [ ] **Step 3: Run verification-before-completion on detached HEAD**

Re-run at minimum unit tests, Python/Node syntax, .NET build, `git diff --check`, `git status --short --branch`, exception-backed saved full reports, and cleanliness checks for `/Users/alex/source/noisemaker`, `/Users/alex/source/noisemaker-for-unity`, and `/Users/alex/nmhlsl-unity`. Record detached HEAD SHA.

- [ ] **Step 4: Finalize the durable evidence and implementation status**

Append the final review verdict and verification-before-completion results to `.superpowers/sdd/task-11-report.md`. Add the Task 9, Task 10, and Task 11 completion lines with their reviewed commit ranges to `.superpowers/sdd/progress.md`; Task 12's final local-main/worktree outcome is reported directly after it happens. Change the design spec status from `Approved` to `Implemented`. Commit only these evidence/status files as `docs: finalize local parity delivery`, then rerun `git diff --check` and the documentation portion of the fresh review if the reviewer requested wording changes.

- [ ] **Step 5: Fast-forward local main directly to the detached SHA**

Require original target checkout clean and still at the expected ancestor, then:

```bash
FINAL_SHA=$(git rev-parse HEAD)
git -C /Users/alex/source/noisemaker-for-unity merge --ff-only "$FINAL_SHA"
test "$(git -C /Users/alex/source/noisemaker-for-unity rev-parse HEAD)" = "$FINAL_SHA"
test "$(git -C /Users/alex/source/noisemaker-for-unity branch --show-current)" = main
git -C /Users/alex/source/noisemaker-for-unity status --short
git -C /Users/alex/source/noisemaker-for-unity branch --list
```

Expected: fast-forward succeeds, local `main` equals the reviewed SHA, status is clean, and only pre-existing local branches (in this task, just `main`) exist.

- [ ] **Step 6: Remove the detached worktree and verify local-only delivery**

From outside the worktree:

```bash
git -C /Users/alex/source/noisemaker-for-unity worktree remove /Users/alex/source/.codex-worktrees/noisemaker-for-unity-v104
git -C /Users/alex/source/noisemaker-for-unity worktree prune
git -C /Users/alex/source/noisemaker-for-unity worktree list
git -C /Users/alex/source/noisemaker-for-unity status --short --branch
git -C /Users/alex/source/noisemaker-for-unity log -1 --oneline
```

Expected: only the original checkout remains, on clean local `main` at the reviewed SHA. Do not push or create a PR.
