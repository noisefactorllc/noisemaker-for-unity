# Final parity review-fix verification

Date: 2026-07-15

## Comparator

- 17/17 subprocess contract tests pass.
- Python compilation and Node syntax checks pass.
- v1.0.104 combined gate: 70 total, 66 `PASS`, 4 `ALLOWED_NEAR`.
- Tiled large-format gate: 3/3 strict `PASS`.
- Original regression gate: 20 total, 18 `PASS`, 2 `ALLOWED_NEAR`.
- An unallowlisted replay of the prior 68-case corpus exits 1 with 64 `PASS` and
  4 `NEAR`, proving the CLI fails closed by default.

## Negative-fractional speed finding

Two programs set Mandala and Sacred Geometry `speed: -1.5`. Reference export and
C# graphdump preserve that exact value, and both graph diffs pass with zero deltas.
With the existing HLSL cast semantics, both focused Unity images pass without an
exception at tolerance 1 (Mandala max byte delta 1; Sacred Geometry byte-exact).
A clean disposable Unity import registered 211/211 shaders and rendered both cases
successfully.

Direct `floor(speed)` was tested rather than assumed. It failed against the fresh
WebGL2 goldens at max deltas 210/207 and SSIM 0.074110/0.228754, so that proposed
edit was reverted. This converts the earlier review item into a measured false
positive while retaining permanent focused coverage.

## Build and repository state

- .NET 8 graphdump Release build: 0 warnings, 0 errors.
- Focused graph parity: 2/2 pass; combined with the unchanged reviewed 302-case
  evidence, canonical coverage is 304/304.
- `git diff --check` passes.
- `/Users/alex/source/noisemaker` and `/Users/alex/nmhlsl-unity` were not modified.
- All new artifacts and logs are under `/private/tmp/noisemaker-task9`.

## Reproduction commands and durable artifact index

Focused reference goldens and graphs:

```bash
PATH=/tmp/nm-node.SoOIaC/nodeenv/bin:$PATH \
NM_REFERENCE_ROOT=/Users/alex/source/noisemaker SHADE_HEADLESS=1 \
node parity/batch-golden.mjs \
  /private/tmp/noisemaker-task9/speed/manifest.tsv \
  /private/tmp/noisemaker-task9/speed/golden \
  --size 127 --time 0.25 --backend webgl2
```

Clean Unity render used for the shader-semantic experiment (the disposable
`Library`, `Temp`, and `Logs` directories were removed immediately beforehand):

```bash
UNITY=/Applications/Unity/Hub/Editor/6000.3.16f1/Unity.app/Contents/MacOS/Unity
"$UNITY" -batchmode -quit \
  -projectPath /tmp/nmhlsl-unity-v104.HKAHvK \
  -logFile /private/tmp/noisemaker-task9/speed/unity-mutant-clean.log \
  -executeMethod Noisemaker.Hlsl.Editor.NMParityRunner.RenderBatchFromCommandLine \
  -nmManifest /private/tmp/noisemaker-task9/speed/render-mutant.tsv \
  -nmSize 127 -nmTime 0.25
```

The two Mandala speed expressions and Sacred Geometry helper were then changed to
direct `floor(speed)`. This exact manifest and Unity invocation reimported and
rendered that candidate:

```bash
awk -F'\t' \
  -v gold=/private/tmp/noisemaker-task9/speed/golden \
  -v out=/private/tmp/noisemaker-task9/speed/candidate-green \
  '{print gold "/" $1 ".graph.json\t" out "/" $1 ".png"}' \
  /private/tmp/noisemaker-task9/speed/manifest.tsv \
  > /private/tmp/noisemaker-task9/speed/render-green.tsv

UNITY=/Applications/Unity/Hub/Editor/6000.3.16f1/Unity.app/Contents/MacOS/Unity
"$UNITY" -batchmode -quit \
  -projectPath /tmp/nmhlsl-unity-v104.HKAHvK \
  -logFile /private/tmp/noisemaker-task9/speed/unity-green.log \
  -executeMethod Noisemaker.Hlsl.Editor.NMParityRunner.RenderBatchFromCommandLine \
  -nmManifest /private/tmp/noisemaker-task9/speed/render-green.tsv \
  -nmSize 127 -nmTime 0.25
```

Comparison that rejected the direct-floor edit:

```bash
python3 parity/batch-compare.py \
  /private/tmp/noisemaker-task9/speed/golden \
  /private/tmp/noisemaker-task9/speed/candidate-green \
  --tolerance 1 --ssim-min 0.9999 \
  --out /private/tmp/noisemaker-task9/speed/green-report.json
# exit 1: max 210/207; SSIM 0.074110/0.228754
```

After restoring the retained cast semantics, this exact Unity command overwrote
`candidate-green` with the final candidate:

```bash
UNITY=/Applications/Unity/Hub/Editor/6000.3.16f1/Unity.app/Contents/MacOS/Unity
"$UNITY" -batchmode -quit \
  -projectPath /tmp/nmhlsl-unity-v104.HKAHvK \
  -logFile /private/tmp/noisemaker-task9/speed/unity-final-cast.log \
  -executeMethod Noisemaker.Hlsl.Editor.NMParityRunner.RenderBatchFromCommandLine \
  -nmManifest /private/tmp/noisemaker-task9/speed/render-green.tsv \
  -nmSize 127 -nmTime 0.25
```

This command accepted both cases without exceptions:

```bash
python3 parity/batch-compare.py \
  /private/tmp/noisemaker-task9/speed/golden \
  /private/tmp/noisemaker-task9/speed/candidate-green \
  --tolerance 1 --ssim-min 0.9999 \
  --out /private/tmp/noisemaker-task9/speed/final-cast-report.json
```

The following results are copied from the machine-readable reports into this
tracked document, so the decision does not depend on `/private/tmp` retention:

| Candidate | Case | Class | Max diff | Mean diff | SSIM | Exceeded pixels | Exceeded channels |
|---|---|---|---:|---:|---:|---:|---:|
| direct `floor(speed)` | Mandala | `FAIL` | 210 | 9.286301072602145 | 0.07411036640405655 | 1942 | 5747 |
| direct `floor(speed)` | Sacred Geometry | `FAIL` | 207 | 14.738343976687954 | 0.2287544459104538 | 4405 | 12802 |
| retained cast | Mandala | `PASS` | 1 | 0.000728501457002914 | 0.9999995827674866 | 0 | 0 |
| retained cast | Sacred Geometry | `PASS` | 0 | 0 | 1.0 | 0 | 0 |

Artifact SHA-256 values at verification time were
`7ef8450b108d3baf5dba5537314c94668907e8d92a1bd4e05cc34fb3f04fc5f0`
for `green-report.json`,
`b3cf43e83389d5013efdcba0184718b89510846884fff65f86d69f70621e2a95`
for `final-cast-report.json`,
`7a6152801db6feadcf18d8b670b889c453d9a527cd0a0e9431c12db10f96ce05`
for `unity-green.log`, and
`7931b95bcfef270baf780183c278e4ecc8eaa4a8117e64d86f6205bff547f0bb`
for `unity-final-cast.log`.

Focused graph parity:

```bash
/tmp/nm-dotnet.FoaV14/dotnet/dotnet build -c Release tools/graphdump
/tmp/nm-dotnet.FoaV14/dotnet/dotnet \
  tools/graphdump/bin/Release/net8.0/graphdump.dll \
  unity/com.noisemaker.hlsl/Effects \
  /private/tmp/noisemaker-task9/speed/graphdump.tsv
python3 parity/graph-diff.py \
  /private/tmp/noisemaker-task9/speed/golden/mandala_negative_fractional_speed.graph.json \
  /private/tmp/noisemaker-task9/speed/graph-cs/mandala_negative_fractional_speed.json
python3 parity/graph-diff.py \
  /private/tmp/noisemaker-task9/speed/golden/sacred_geometry_negative_fractional_speed.graph.json \
  /private/tmp/noisemaker-task9/speed/graph-cs/sacred_geometry_negative_fractional_speed.json
```

Final regression gates:

```bash
python3 -m unittest discover -s parity/tests -p 'test_*.py' -v
python3 parity/batch-compare.py \
  /private/tmp/noisemaker-task9/v104-combined/golden \
  /private/tmp/noisemaker-task9/v104-combined/candidate \
  --tolerance 1 --ssim-min 0.9999 \
  --exceptions parity/programs/v104/exceptions.json \
  --out /private/tmp/noisemaker-task9/v104-combined/report.json
python3 parity/batch-compare.py \
  /tmp/nmhlsl-v104-tiled-golden \
  /private/tmp/noisemaker-task8/tiled/candidate-batch-final \
  --tolerance 1 --ssim-min 0.9999 \
  --out /private/tmp/noisemaker-task9/tiled-report.json
python3 parity/batch-compare.py \
  /private/tmp/noisemaker-task8/original/golden \
  /private/tmp/noisemaker-task8/original/candidate-batch-final \
  --tolerance 1 --ssim-min 0.9999 \
  --exceptions parity/programs/exceptions.json \
  --out /private/tmp/noisemaker-task9/original-report.json
```

Artifact reports: `speed/green-report.json` (rejected direct-floor edit),
`speed/final-cast-report.json` (retained semantics), `v104-combined/report.json`,
`tiled-report.json`, and `original-report.json` under
`/private/tmp/noisemaker-task9`.
