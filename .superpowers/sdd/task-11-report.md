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
With the existing HLSL cast semantics, both focused Unity images pass strict byte
comparison. A clean disposable Unity import registered 211/211 shaders and rendered
both cases successfully.

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
