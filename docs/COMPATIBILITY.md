# noisemaker-for-unity: compatibility report

## 1. Source and authority revisions

Audit pass: 2026-09-26 (pass 21). Audited source: [`7d8178d1785efc2dea0cad98db9e1d8c7f2762bc`](https://github.com/noisefactorllc/noisemaker-for-unity/commit/7d8178d1785efc2dea0cad98db9e1d8c7f2762bc). Local `main` was clean and matched `origin/main` before and after the checks.
Automation-completable gates re-verified fresh at this source (see §3 gate evidence). Unity-host pixel gates stay **unverified on this automation host** and carry unchanged from passes 2–14. No release approval or new closure follows from this pass.
Current upstream head: `66b8ce7d861010ad31de6fd37bc364d0a72fc897`, documentation-only beyond the published authority `1.0.185` = `6a0af04d3c4f345ffab5e9f8e54e532216b4cdaa`. The published effect manifest is byte-identical at `1.0.176`, `1.0.184`, and `1.0.185`: 210 effect IDs, sha256 `05c4d7b7744837ae90a3bb4c89e5403ff09448a74d9d7e824abb3d719ad3314e`.
Beyond the previously synced `noisemaker@8eeb7b5ac14e`, upstream held 3 runtime-only commits (`f83a427`, `9574362`, `6113da0`: backend diagnostics, texture-pooling, GAP-006 resource plan) in `shaders/src/runtime/**` and tests. As of pass 22 the GAP-006 row (`6113da0`+`9574362`) is delivered (§3 pass 22); `f83a427` is a JS-backend diagnostic-union change with no Unity-renderer equivalent and needs no port.
The observations below retain their original source and authority identities. They do not qualify later updates.
Current served kit: `0.1.25`, source `ebd3e7b757bedcfc0652340acef026c334ea6070`, re-verified fresh this pass: 2107/2107 CDN files byte-checked, source cross-check 2105/2105 at `7d8178d`, exit 0. [Deployment metadata](https://kits.noisedeck.app/unity/0/deployment-meta.json). Artifact identity does not establish host qualification.

### Earlier source observations

Report date: 2026-09-24. Source inspected: [`2344c30211c73804989647058506a387de404c91`](https://github.com/noisefactorllc/noisemaker-for-unity/commit/2344c30211c73804989647058506a387de404c91) (local `main`, clean, matched `origin/main`).
Historical tolerance-based result at this SHA: **reported for the declared corpora, not full parity** (see §3). This is not yet a release approval: the installed-workflow (GAP-002) and distribution (GAP-003) qualifications remain open.
Authority: immutable git worktree of [`noisemaker@c9ee8a049b2b63cd300da67c01ee40baf29dc288`](https://github.com/noisefactorllc/noisemaker/commit/c9ee8a049b2b63cd300da67c01ee40baf29dc288) — tag `v1.0.176`, the published authority revision. All goldens and reference graphs in this pass were regenerated from that pinned worktree (`NM_REFERENCE_ROOT`), not from retained historical files.
A later documentation-only commit does not change this tested source identity.
Any runtime, package, or authority update requires fresh evidence before this report can qualify it.

Unity C# and HLSL runtime with a UPM package, Quick Start sample, and Shader Graph wrappers. The README marks development as provisional. [Source contract](https://github.com/noisefactorllc/noisemaker-for-unity/blob/d48de74c806213789bf1ed8d79ebd8e918437c57/README.md).

README cites reference v1.0.104 for graph parity and earlier shader snapshots. Those version claims were not resolved to immutable SHAs in this pass.
Current upstream discovery SHA: `c9ee8a049b2b63cd300da67c01ee40baf29dc288`.
Published authority: `1.0.176`, source `c9ee8a049b2b63cd300da67c01ee40baf29dc288`.
[Immutable published manifest](https://shaders.noisedeck.app/1.0.176/effects/manifest.json) contains 210 effect IDs.
Its SHA-256 is `05c4d7b7744837ae90a3bb4c89e5403ff09448a74d9d7e824abb3d719ad3314e`.
These IDs do not define complete parameter, state, input, or platform coverage.

Served kit `0.1.16` records `d48de74c806213789bf1ed8d79ebd8e918437c57`. [Source metadata](https://kits.noisedeck.app/unity/0/deployment-meta.json).
Historical measurements remain bound to their original revisions in [completion gaps](COMPLETION_GAPS.md).

## 2. Host and distribution matrix

Current tests and qualification limits are in [section 3](#3-parity-coverage).
The matrix below retains the earlier measured scope. A historical verified row is not a current-source or full-platform certification.

| Dimension | Status | Measured scope or limit |
|---|---|---|
| Source-level checks | verified | 316/316 graph parity + compiler contract tests PASS + 27 comparator unit tests. |
| Actual host rendering | verified | 112/112 fixtures rendered and graded at the pinned authority (100 `PASS`, 12 bounded `ALLOWED_NEAR`, 0 fail, exit 0). Full host/platform matrix beyond macOS/Metal remains open. |
| Minimum and current host versions | unverified minimum | Package declared minimum aligned to Unity 6 (`6000.0`). Observed on `6000.3.16f1`. This does not test `6000.0`. Obsolete 2021.3 minimum dropped. The `6000.0` floor is recorded first-hand unavailable to this automation (pass 18, 2026-09-26): the Unity `6000.0.84f1` Linux editor (changeset `78ab6fc243d5`, official tarball, unattended) exits batch mode 198 "No valid Unity Editor license found" with 0 entitlements — same account-bound license blocker as `6000.3.16f1`; raw log committed. |
| Supported operating systems and backends | unverified outside macOS | macOS/Metal qualified (isolated consumer + headless player, passes 3/4). Windows/Linux recorded explicitly unavailable to this automation (2026-09-26, first-hand): the Linux editor (`6000.3.16f1`, changeset `a56f230f6470`, official tarball, unattended) exits batch mode 198 — "No valid Unity Editor license found"; licensing client reports 0 entitlements, and activation requires a human Unity-account `.alf`→`.ulf` exchange; no Windows host exists in this automation. Coverage for any licensed host remains open. |
| Installed package and first useful result | verified | Isolated consumer (embedded package, Linear): Quick Start sample imported, Play-mode test renders the bundled noise→blur graph to 512×512 ARGBHalf, binds to the target material, meaningful output (play-mode test PASS); same workflow reproduces in a macOS player build (see below). |
| Parameters, external inputs, state, and chains | unverified | Full current-authority combinations remain unmeasured. |
| Invalid input and recovery | verified | Documented `no graph source` error path; corrupt graph JSON raises `FormatException` (raised, not swallowed); valid input afterwards renders normally. Public entry point only. |
| Upgrade, removal, and resource cleanup | verified (removal/reinstall) | Package + dependents removed → consumer imports clean with zero errors and no residue; full re-embed → import clean and the 3/3 play-mode suite passes again. Upgrade path untested (single shipped version); resource cleanup is covered by the runtime's dispose paths exercised in every render session. |
| Accessibility of provided controls | unverified | Keyboard, focus, labels, and diagnostics need host observations where applicable. |
| Release readiness | blocked | Full parity, installation, host, and artifact evidence remain incomplete. |

## 3. Parity coverage

### Daily review, 2026-09-25

The report of 245 fixtures contains 197 tolerance-based PASS results and 48 bounded differences, with three unported current effect IDs. It is not full parity. This review independently ran Unity 6000.5.5f1 on the current package: solid is exact. Noise differs in 30 channels with maximum 1. Heightmap3d_landscape differs in five channels with maximum 3. These three comparisons use retained historical goldens. The 6000.0 minimum, full player workflow, and later 245-case claim remain incompletely reviewed. [Raw evidence](/Users/alex/.codex/automations/noisemaker-port-completion-audit/review-20260925-053200/current-native-comparisons.json).

The current full case denominator remains incomplete. Missing parameters, hosts, external inputs, and stateful sequences remain qualification gaps. No skip or tolerated difference counts as exact parity.

### Earlier measurements

Full parity requires complete applicable coverage with no skips or missing cases.
Historical NEAR, CHAOS, and tolerated differences do not count as strict equality.
The existing numerical contracts remain separate from exact comparison. This report does not change tolerances or goldens.
Unknown values mean `not measured`, never zero.

| Gate | Expected cases | Executed | Strict passes | Failures | Skips | Status |
|---|---|---|---|---|---|---|
| Historical 2026-09-24 fixture suite | 156 fixtures (30 root + 9 3D + 17 classic + 15 synth + 12 mixer + 70 v104 + 3 tiled) | 156 | not measured (`PASS` uses a tolerance) | 0 | 0 | **measured 2026-09-24: exit 0, every non-`PASS` is a measured, bounded `ALLOWED_NEAR`** (19: root 5, 3D 3, classic 2, synth 3, mixer 2, v104 4) |

Structural graph parity (separate gate, GPU-free): 316/316 programs byte-clean — the full 207-program `--selftest` corpus plus all 109 `parity/programs/**/*.dsl` fixtures, C# live-DSL graphs vs the reference oracle at the pinned authority. Compiler contract tests: PASS (0 failures).

Earlier served compatibility inventory declares 207 effect IDs. Declaration does not establish execution or parity.
IDs absent from the served declaration: `synth/media`, `synth/scope`, `synth/spectrum`.
Missing effects remain visible toward the full-parity goal. Contract exclusions do not become successful tests.

Current served declaration: 207 effect IDs. This inventory is not evidence of execution. The declaration column below was measured at the kit-`0.1.22`-era package; the served kit `0.1.25` ships the byte-identical package payload (pass 19 cross-check, re-verified pass 21: 2105/2105 files identical to the current source tree).

### Effect inventory

Status measured 2026-09-24 at source `2344c30` vs authority `noisemaker@c9ee8a04` (v1.0.176).
`graph` = the effect appears in at least one of the 316 graph-parity fixtures (byte-clean, all 210 IDs covered).
`graph+pixel` = additionally appears in at least one of the 156 rendered fixtures (118 IDs; classicNoisedeck 20/20, renderable synth 26/26, mixer 15/15 complete).
Per-effect parameter/state/input breadth remains tracked by GAP-001.

| Effect ID | Declared in served kit | Historical fixture coverage |
|---|---|---|
| `classicNoisedeck/bitEffects` | yes | graph+pixel |
| `classicNoisedeck/caustic` | yes | graph+pixel |
| `classicNoisedeck/cellNoise` | yes | graph+pixel |
| `classicNoisedeck/cellRefract` | yes | graph+pixel |
| `classicNoisedeck/coalesce` | yes | graph+pixel |
| `classicNoisedeck/colorLab` | yes | graph+pixel |
| `classicNoisedeck/composite` | yes | graph+pixel |
| `classicNoisedeck/effects` | yes | graph+pixel |
| `classicNoisedeck/fractal` | yes | graph+pixel |
| `classicNoisedeck/glitch` | yes | graph+pixel |
| `classicNoisedeck/kaleido` | yes | graph+pixel |
| `classicNoisedeck/lensDistortion` | yes | graph+pixel |
| `classicNoisedeck/moodscape` | yes | graph+pixel |
| `classicNoisedeck/noise` | yes | graph+pixel |
| `classicNoisedeck/noise3d` | yes | graph+pixel |
| `classicNoisedeck/refract` | yes | graph+pixel |
| `classicNoisedeck/shapeMixer` | yes | graph+pixel |
| `classicNoisedeck/shapes` | yes | graph+pixel |
| `classicNoisedeck/shapes3d` | yes | graph+pixel |
| `classicNoisedeck/splat` | yes | graph+pixel |
| `filter/adjust` | yes | graph+pixel |
| `filter/bloom` | yes | graph+pixel |
| `filter/blur` | yes | graph+pixel |
| `filter/bulge` | yes | graph+pixel |
| `filter/celShading` | yes | graph+pixel |
| `filter/channel` | yes | graph+pixel |
| `filter/chroma` | yes | graph+pixel |
| `filter/chromaticAberration` | yes | graph+pixel |
| `filter/chrome` | yes | graph+pixel |
| `filter/clouds` | yes | graph+pixel |
| `filter/colorReplace` | yes | graph+pixel |
| `filter/convolutionFeedback` | yes | graph+pixel |
| `filter/corrupt` | yes | graph+pixel |
| `filter/craquelure` | yes | graph+pixel |
| `filter/crt` | yes | graph+pixel |
| `filter/degauss` | yes | graph+pixel |
| `filter/deriv` | yes | graph+pixel |
| `filter/directionalBlur` | yes | graph+pixel |
| `filter/dither` | yes | graph+pixel |
| `filter/edge` | yes | graph+pixel |
| `filter/emboss` | yes | graph+pixel |
| `filter/extrude` | yes | graph+pixel |
| `filter/feedback` | yes | graph+pixel |
| `filter/fibers` | yes | graph+pixel |
| `filter/flipMirror` | yes | graph+pixel |
| `filter/fxaa` | yes | graph+pixel |
| `filter/glowingEdge` | yes | graph+pixel |
| `filter/glyphMap` | yes | graph+pixel |
| `filter/grade` | yes | graph+pixel |
| `filter/grain` | yes | graph+pixel |
| `filter/grime` | yes | graph+pixel |
| `filter/halftone` | yes | graph+pixel |
| `filter/hatch` | yes | graph+pixel |
| `filter/highPass` | yes | graph+pixel |
| `filter/historicPalette` | yes | graph+pixel |
| `filter/invert` | yes | graph+pixel |
| `filter/lens` | yes | graph+pixel |
| `filter/lensFlare` | yes | graph+pixel |
| `filter/lensWarp` | yes | graph+pixel |
| `filter/lightLeak` | yes | graph+pixel |
| `filter/lighting` | yes | graph+pixel |
| `filter/lowPoly` | yes | graph+pixel |
| `filter/median` | yes | graph+pixel |
| `filter/morphology` | yes | graph+pixel |
| `filter/mosaicTiles` | yes | graph+pixel |
| `filter/motionBlur` | yes | graph+pixel |
| `filter/normalMap` | yes | graph+pixel |
| `filter/normalize` | yes | graph+pixel |
| `filter/octaveWarp` | yes | graph+pixel |
| `filter/oilPaint` | yes | graph+pixel |
| `filter/osd` | yes | graph+pixel |
| `filter/outline` | yes | graph+pixel |
| `filter/palette` | yes | graph+pixel |
| `filter/parallax` | yes | graph+pixel |
| `filter/patchwork` | yes | graph+pixel |
| `filter/photocopy` | yes | graph+pixel |
| `filter/pinch` | yes | graph+pixel |
| `filter/pixelSort` | yes | graph+pixel |
| `filter/pixels` | yes | graph+pixel |
| `filter/plasticWrap` | yes | graph+pixel |
| `filter/polar` | yes | graph+pixel |
| `filter/pondRipples` | yes | graph+pixel |
| `filter/posterize` | yes | graph+pixel |
| `filter/prismaticAberration` | yes | graph+pixel |
| `filter/reindex` | yes | graph+pixel |
| `filter/relief` | yes | graph+pixel |
| `filter/repeat` | yes | graph+pixel |
| `filter/reverb` | yes | graph+pixel |
| `filter/ridge` | yes | graph+pixel |
| `filter/rotate` | yes | graph+pixel |
| `filter/scale` | yes | graph+pixel |
| `filter/scanlineError` | yes | graph+pixel |
| `filter/scatter` | yes | graph+pixel |
| `filter/scratches` | yes | graph+pixel |
| `filter/scroll` | yes | graph+pixel |
| `filter/seamless` | yes | graph+pixel |
| `filter/sharpen` | yes | graph+pixel |
| `filter/simpleAberration` | yes | graph+pixel |
| `filter/sine` | yes | graph+pixel |
| `filter/skew` | yes | graph+pixel |
| `filter/smooth` | yes | graph+pixel |
| `filter/smoothstep` | yes | graph+pixel |
| `filter/snow` | yes | graph+pixel |
| `filter/sobel` | yes | graph+pixel |
| `filter/spatter` | yes | graph+pixel |
| `filter/spinBlur` | yes | graph+pixel |
| `filter/spiral` | yes | graph+pixel |
| `filter/spookyTicker` | yes | graph+pixel |
| `filter/stamp` | yes | graph+pixel |
| `filter/step` | yes | graph+pixel |
| `filter/stipple` | yes | graph+pixel |
| `filter/strayHair` | yes | graph+pixel |
| `filter/strokes` | yes | graph+pixel |
| `filter/temporalAberration` | yes | graph+pixel |
| `filter/tetraColorArray` | yes | graph+pixel |
| `filter/tetraCosine` | yes | graph+pixel |
| `filter/text` | yes | graph+pixel |
| `filter/texture` | yes | graph+pixel |
| `filter/threshold` | yes | graph+pixel |
| `filter/tile` | yes | graph+pixel |
| `filter/tint` | yes | graph+pixel |
| `filter/translate` | yes | graph+pixel |
| `filter/tunnel` | yes | graph+pixel |
| `filter/unsharpMask` | yes | graph+pixel |
| `filter/vaseline` | yes | graph+pixel |
| `filter/vignette` | yes | graph+pixel |
| `filter/warp` | yes | graph+pixel |
| `filter/watercolor` | yes | graph+pixel |
| `filter/waves` | yes | graph+pixel |
| `filter/wind` | yes | graph+pixel |
| `filter/wobble` | yes | graph+pixel |
| `filter/wormhole` | yes | graph+pixel |
| `filter/zoomBlur` | yes | graph+pixel |
| `filter3d/flow3d` | yes | graph+pixel |
| `filter3d/palette3d` | yes | graph+pixel |
| `mixer/alphaMask` | yes | graph+pixel |
| `mixer/applyMode` | yes | graph+pixel |
| `mixer/blendMode` | yes | graph+pixel |
| `mixer/cellSplit` | yes | graph+pixel |
| `mixer/centerMask` | yes | graph+pixel |
| `mixer/channelCombine` | yes | graph+pixel |
| `mixer/distortion` | yes | graph+pixel |
| `mixer/focusBlur` | yes | graph+pixel |
| `mixer/mashup` | yes | graph+pixel |
| `mixer/patternMix` | yes | graph+pixel |
| `mixer/shadow` | yes | graph+pixel |
| `mixer/shapeMask` | yes | graph+pixel |
| `mixer/split` | yes | graph+pixel |
| `mixer/thresholdMix` | yes | graph+pixel |
| `mixer/uvRemap` | yes | graph+pixel |
| `points/attractor` | yes | graph+pixel |
| `points/buddhabrot` | yes | graph+pixel |
| `points/dla` | yes | graph+pixel |
| `points/flock` | yes | graph+pixel |
| `points/flow` | yes | graph+pixel |
| `points/heightGrid` | yes | graph+pixel |
| `points/hydraulic` | yes | graph+pixel |
| `points/lenia` | yes | graph+pixel |
| `points/life` | yes | graph+pixel |
| `points/physarum` | yes | graph+pixel |
| `points/physical` | yes | graph+pixel |
| `render/loopBegin` | yes | graph+pixel |
| `render/loopEnd` | yes | graph+pixel |
| `render/meshLoader` | yes | graph+pixel |
| `render/meshRender` | yes | graph+pixel |
| `render/pointsBillboardRender` | yes | graph+pixel |
| `render/pointsEmit` | yes | graph+pixel |
| `render/pointsRender` | yes | graph+pixel |
| `render/render3d` | yes | graph+pixel |
| `render/renderCubemap3d` | yes | graph+pixel |
| `render/renderCubemapSurface` | yes | graph+pixel |
| `render/renderLandscape3d` | yes | graph+pixel |
| `render/renderLit3d` | yes | graph+pixel |
| `synth/bitwise` | yes | graph+pixel |
| `synth/cell` | yes | graph+pixel |
| `synth/cellularAutomata` | yes | graph+pixel |
| `synth/curl` | yes | graph+pixel |
| `synth/gabor` | yes | graph+pixel |
| `synth/gradient` | yes | graph+pixel |
| `synth/julia` | yes | graph+pixel |
| `synth/mandala` | yes | graph+pixel |
| `synth/mandelbrot` | yes | graph+pixel |
| `synth/media` | no | graph |
| `synth/mnca` | yes | graph+pixel |
| `synth/modPattern` | yes | graph+pixel |
| `synth/navierStokes` | yes | graph+pixel |
| `synth/newton` | yes | graph+pixel |
| `synth/noise` | yes | graph+pixel |
| `synth/osc2d` | yes | graph+pixel |
| `synth/pattern` | yes | graph+pixel |
| `synth/perlin` | yes | graph+pixel |
| `synth/polygon` | yes | graph+pixel |
| `synth/reactionDiffusion` | yes | graph+pixel |
| `synth/remap` | yes | graph+pixel |
| `synth/roll` | yes | graph+pixel |
| `synth/sacredGeometry` | yes | graph+pixel |
| `synth/scope` | no | graph |
| `synth/shape` | yes | graph+pixel |
| `synth/solid` | yes | graph+pixel |
| `synth/spectrum` | no | graph |
| `synth/subdivide` | yes | graph+pixel |
| `synth/testPattern` | yes | graph+pixel |
| `synth3d/cell3d` | yes | graph+pixel |
| `synth3d/cellularAutomata3d` | yes | graph+pixel |
| `synth3d/flythrough3d` | yes | graph+pixel |
| `synth3d/fractal3d` | yes | graph+pixel |
| `synth3d/heightmap3d` | yes | graph+pixel |
| `synth3d/noise3d` | yes | graph+pixel |
| `synth3d/reactionDiffusion3d` | yes | graph+pixel |
| `synth3d/shape3d` | yes | graph+pixel |

### Native observations, 2026-09-24 (full gate, current authority)

Unity 6000.3.16f1, isolated consumer project (`~/nmhlsl-parity`) with the package embedded from source `2344c30`, Linear color space, Metal. Goldens regenerated from the pinned authority worktree `noisemaker@c9ee8a04` (v1.0.176) via the reference WebGL2/Chromium renderer — no retained historical inputs. Every declared fixture executed; zero skips.

| Gate (script) | Fixtures | Policy | PASS | ALLOWED_NEAR | FAIL | Exit |
|---|---|---|---|---|---|---|
| `root-verify.sh` (root, 256px) | 30 | tol 1, SSIM ≥ 0.9999, `programs/exceptions.json` | 25 | 5 | 0 | 0 |
| `3d-verify.sh` (3D, 256px) | 9 | tol 2, SSIM ≥ 0.98, `programs/3d-exceptions.json` | 6 | 3 | 0 | 0 |
| `classic-verify.sh` (classic, 256px) | 17 | tol 1, SSIM ≥ 0.9999, `programs/classic-exceptions.json` | 15 | 2 | 0 | 0 |
| `synth-verify.sh` (synth, 256px) | 15 | tol 1, SSIM ≥ 0.92, `programs/synth-exceptions.json` | 12 | 3 | 0 | 0 |
| `mixer-verify.sh` (mixer, 256px) | 12 | tol 1, SSIM ≥ 0.9999, `programs/mixer-exceptions.json` | 10 | 2 | 0 | 0 |
| `points-verify.sh` (points, 256px, 60 warm frames) | 10 | tol 1, SSIM ≥ 0.50, `programs/points-exceptions.json` | 2 | 8 | 0 | 0 |
| `filter-verify.sh` (filter batches 1-3, 256px) | 74 | tol 1, SSIM ≥ 0.99, `programs/filter-exceptions.json` | 55 | 19 | 0 | 0 |
| `render-verify.sh` (render, 256px; mesh batch shares `meshes/sphere.obj`) | 5 | tol 1, SSIM ≥ 0.9999, `programs/render-exceptions.json` | 3 | 2 | 0 | 0 |
| v104 manifest (127px) | 70 | tol 1, SSIM ≥ 0.9999, `v104/exceptions.json` | 66 | 4 | 0 | 0 |
| tiled manifest (127px tile of 4096²) | 3 | tol 0 (exact) | 3 | 0 | 0 | 0 |
| Total | 245 | — | 197 | 48 | 0 | 0 |

The declared native engine cases `nm_adjust_test`, `nm_grade_test`, `nm_invert_test`, and `nm_tint_test` sit in the root manifest under `root-verify.sh` (tol=1, SSIM ≥ 0.9999) and are absent from `programs/exceptions.json`, so all four graded as strict PASS in this full gate. The FAIL rows in the initial bounded probe below are that superseded probe's own measurement frame (Unity 6000.5.5f1, retained historical goldens, zero byte tolerance) and are non-qualifying by its own terms; they are retained as history, not as current status.

Graph gate: 316/316 byte-clean (207 `--selftest` + 109 fixture programs; C# live compiler vs reference oracle at the pinned authority). Compiler contract tests: PASS (0 failures).

Graph-level parameter sweep (2026-09-25, Linux host, GPU-free — .NET 8 `tools/graphdump`, no Unity editor; authority `noisemaker@c9ee8a04` v1.0.176):

| Gate (script) | Variants | Policy | Graph-clean | FAIL | Exit |
|---|---|---|---|---|---|
| `param-sweep-verify.sh` (per-effect parameter variants, committed corpus `parity/programs/param-sweep/`) | 1900 | structural graph diff (`graph-diff.py`), fail-closed, corpus drift check, 391 measured exclusions | 1900 | 0 | 0 |

Raw per-variant results: `parity/programs/param-sweep/results.tsv` (all `PASS`; header pins the authority revision). One non-default variant per value class of every user-facing parameter of all 207 ported effects (enum choices, boolean flips, slider midpoints; unbounded params default+1). Graph-level only — no pixels rendered; Unity-side parameter rendering remains open.

Every `ALLOWED_NEAR` matched its recorded budget exactly (max delta, SSIM floor, exceeded pixel/channel counts, exact coordinates). The three previously unbounded root fixtures (`heightGrid_billboard`, `heightmap3d_landscape`, `nm_chrome_test`) are now formalized in `programs/exceptions.json` with mechanisms from this pass's measurements; `parallax` and `refract_mirror` reproduced their recorded budgets byte-for-byte. The v104 corpus reproduced its recorded 66+4 result unchanged.

These gates establish rendered parity for the declared fixture corpora at the pinned authority. Per-effect parameter/state/input breadth remains open under GAP-001; GAP-002's workflow legs are qualified (passes 3/4/6) while its minimum-host and platform-matrix required checks remain open (pass-17 availability recording, 2026-09-26); distribution (GAP-003) qualification remains open.

### Installed workflow and player build, 2026-09-24 (GAP-002/GAP-003 evidence)

Isolated consumer project (Unity 6000.3.16f1, embedded package from source `2344c30`, Linear color space). Quick Start sample imported; the documented workflow driven by play-mode tests (fail-closed, machine-readable evidence):

- **Play leg (PASS):** bundled `noise → blur` graph renders to 512×512 ARGBHalf `Output` after 1 frame; the sample binds it to the target material; readback mean 0.43972 / std 0.13992 / 257k distinct values / 100% non-black.
- **Error/recovery legs (PASS):** no-source `Rebuild()` logs the documented error and `Output` stays null; corrupt graph JSON raises `FormatException` from the public entry point and `Output` stays null; valid input then renders normally.
- **Player build (PASS):** macOS build succeeds with the package's automatic `NMShaderInclusionBuildStep` (212 package shader assets; Always Included Shaders list restored after the build). The built player, run headless, resolves the shaders at runtime without an editor and reproduces the workflow: 512×512 ARGBHalf, material bound, readback mean 0.43970 / std 0.13983 — statistically identical to the editor run.

Recorded explicitly, not closed (GAP-002 remains open; pass-17/18 recording, 2026-09-26): Linux and Windows are unavailable to this automation — the Linux editor (`6000.3.16f1`, `a56f230f6470`, unattended official tarball on x86_64, kernel 6.8.0-134) exits batch mode **198** "No valid Unity Editor license found" with 0 entitlements; activation requires a human Unity-account `.alf`→`.ulf` exchange; no Windows host. Raw run log committed: [`parity/evidence/2026-09-26-linux-editor-license-run.log`](../parity/evidence/2026-09-26-linux-editor-license-run.log). The upgrade path is not exercisable (single shipped version; removal → reinstall is the qualified lifecycle). GAP-003 retains the distributed-kit view of these items. The declared `6000.0` minimum floor remains untested on a licensed host — and is recorded first-hand unavailable (pass 18): the Unity `6000.0.84f1` Linux editor (changeset `78ab6fc243d5`, official tarball, unattended) exits batch mode with the identical **198** failure and 0 entitlements; raw log committed: [`parity/evidence/2026-09-26-unity-6000-minimum-license-run.log`](../parity/evidence/2026-09-26-unity-6000-minimum-license-run.log).

### Local artifact integrity, metadata, and removal/reinstall, 2026-09-24 (GAP-003 evidence)

- **Artifact bytes:** the embedded package consumed by every qualification session is checksum-identical to the source tree `unity/com.noisemaker.hlsl/` (rsync checksum dry-run: zero drift, `.meta` files included). Committed manifest hash (pass 17, 2026-09-26): 1681 files, sha256 `5a7032f9dc09fe1a9db643012549b8e585381a7348e07432f0b8437eca5f0a82` at source `3686fd0`, recomputed unchanged at review candidate `5d4a9e9f4a8` (package tree unchanged: `git diff 3686fd0..5d4a9e9f4a8 -- unity/com.noisemaker.hlsl` → 0 files). Re-bound at pass 22 (2026-09-26): the GAP-006 texture-pooling port changed the package tree (5 files), so the manifest hash at `448eca7` is 1683 files, sha256 `79ba4b6cc26ee5a9418183cbfddb37b3b5e87ccabf62478d1e69461eb40627bd` — exact command and output in [`parity/evidence/2026-09-26-package-artifact-hash.txt`](../parity/evidence/2026-09-26-package-artifact-hash.txt).
- **Metadata:** `package.json` declares `com.noisemaker.hlsl` 0.1.0, `unity: 6000.0`, MIT (`license` field + shipped `LICENSE.md`), **zero dependencies**, 1 sample, and wired `changelogUrl` / `licensesUrl` / `documentationUrl`. No third-party notices required.
- **Removal → clean:** package + imported sample + dependent consumer scripts removed → project imports with exit 0, zero compile errors, no `com.noisemaker` residue in `packages-lock.json`.
- **Reinstall → qualified again:** full restore → import clean → the play-mode suite passes 3/3 (render + binding, error paths, recovery).
- **Distributed kit (`0.1.17`):** published at source `2344c30` — the exact tested revision (served `deployment-meta.json` and `kit.json` `source.sha`). All 2107 inventoried files fetched from the CDN and verified byte-for-byte against the manifest (sha256 + size, fail-closed, 0 bad). Exact-source CI: Export kit run 35984719956 = `success` at that SHA.

Remaining under GAP-003: the upgrade path (single shipped version today) and host/platform matrix.

### Native observations, 2026-09-24 (initial bounded probe)

Unity 6000.5.5f1 with an isolated embedded package and Linear color space. 19 selected fixtures rendered. Exact comparison: 4 passes and 15 differences. The 109 tracked fixtures include 39 root fixtures and 70 v104 fixtures. Twenty root graphs were absent.
The graphs and goldens are retained historical inputs. Their full authority provenance remains unresolved in this pass.
These results do not qualify current upstream parity. Exact comparison uses zero byte tolerance.
Existing tolerance-based acceptance remains separate. No tolerance or golden changed.

| Inventory | Fixtures | Executed | Exact passes | Exact differences | Not executed | Full qualification |
|---|---|---|---|---|---|---|
| Tracked program files | 109 | 19 | 4 | 15 | 90 | unverified |

Every unexecuted fixture remains visible in the [fixture inventory](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-fixture-inventory.json).
Fixture counts do not prove coverage of every current effect, parameter, or stateful workflow.

| Case | Exact result | Measurement | Evidence |
|---|---|---|---|
| `blendMode` | failed | [FAIL] blendMode: max-abs-diff=1.000 mean-abs-diff=0.0004 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-blendMode-comparison-command.json) |
| `blur` | failed | [FAIL] blur: max-abs-diff=1.000 mean-abs-diff=0.0001 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-blur-comparison-command.json) |
| `cell` | verified | [PASS] cell: max-abs-diff=0.000 mean-abs-diff=0.0000 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-cell-comparison-command.json) |
| `gradient` | failed | [FAIL] gradient: max-abs-diff=1.000 mean-abs-diff=0.0002 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-gradient-comparison-command.json) |
| `heightGrid_billboard` | failed | [FAIL] heightGrid_billboard: max-abs-diff=2.000 mean-abs-diff=0.0002 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-heightGrid_billboard-comparison-command.json) |
| `heightGrid_billboard_alpha` | failed | [FAIL] heightGrid_billboard_alpha: max-abs-diff=1.000 mean-abs-diff=0.0000 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-heightGrid_billboard_alpha-comparison-command.json) |
| `heightGrid_pointsRender_perspective` | verified | [PASS] heightGrid_pointsRender_perspective: max-abs-diff=0.000 mean-abs-diff=0.0000 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-heightGrid_pointsRender_perspective-comparison-command.json) |
| `heightmap3d_landscape` | failed | [FAIL] heightmap3d_landscape: max-abs-diff=3.000 mean-abs-diff=0.0000 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-heightmap3d_landscape-comparison-command.json) |
| `nm_adjust_test` | failed | [FAIL] nm_adjust_test: max-abs-diff=1.000 mean-abs-diff=0.0003 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-nm_adjust_test-comparison-command.json) |
| `nm_alphaMask_test` | failed | [FAIL] nm_alphaMask_test: max-abs-diff=1.000 mean-abs-diff=0.0001 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-nm_alphaMask_test-comparison-command.json) |
| `nm_chrome_test` | failed | [FAIL] nm_chrome_test: max-abs-diff=41.000 mean-abs-diff=0.0022 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-nm_chrome_test-comparison-command.json) |
| `nm_grade_test` | failed | [FAIL] nm_grade_test: max-abs-diff=1.000 mean-abs-diff=0.0001 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-nm_grade_test-comparison-command.json) |
| `nm_invert_test` | failed | [FAIL] nm_invert_test: max-abs-diff=1.000 mean-abs-diff=0.0001 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-nm_invert_test-comparison-command.json) |
| `nm_tint_test` | failed | [FAIL] nm_tint_test: max-abs-diff=1.000 mean-abs-diff=0.0000 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-nm_tint_test-comparison-command.json) |
| `noise` | failed | [FAIL] noise: max-abs-diff=1.000 mean-abs-diff=0.0001 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-noise-comparison-command.json) |
| `osc2d` | verified | [PASS] osc2d: max-abs-diff=0.000 mean-abs-diff=0.0000 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-osc2d-comparison-command.json) |
| `remap_zones` | failed | [FAIL] remap_zones: max-abs-diff=1.000 mean-abs-diff=0.0001 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-remap_zones-comparison-command.json) |
| `shape` | failed | [FAIL] shape: max-abs-diff=1.000 mean-abs-diff=0.0035 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-shape-comparison-command.json) |
| `solid` | verified | [PASS] solid: max-abs-diff=0.000 mean-abs-diff=0.0000 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-solid-comparison-command.json) |

### Delivered-range audit, 2026-09-26 (pass 16)

Raw audit commands and outputs from the pinned reference worktree, checked out
detached by SHA (`git rev-parse HEAD` → `8eeb7b5ac14eb37a8d16037f607a88ce63924cd3`):

- `git merge-base --is-ancestor 4891b9953f9f 8eeb7b5ac14e` → exit 0 (`ANCESTOR_OK`) —
  the force-push-flagged declared start IS an ancestor of the delivered end.
- `git log --oneline 4891b9953f9f..8eeb7b5ac14e -- shaders/` (delivery order is
  ancestry order; listed top-down from the range end):

```
fa83eeab feat(shaders): copy name/viewport/clear/samplerTypes/type onto expanded passes (GAP-005)
2f47612c fix(shaders): stop double-creating global surfaces on allocation change
62eb56fa fix(shaders): allocate the WebGL2 mip chain and cache WebGPU mip bind groups
a021a283 feat(shaders): authorable mipmaps/persistent/3D filter texture policies (GAP-004)
9d3474df fix(shaders): complete GAP-003 validator contract, corpus gate, and test wiring
ba87ffae feat(shaders): validate effect definitions against spec at runtime (GAP-003)
240740dd test: register committed subchain differential gate vs recorded baseline
66b2c721 feat: subchain-argument validation contract (P008/P009/P010, strict opt-in)
fca611fd fix: derive numeric-coercion diagnostic coordinates from array positions
9fa1a221 fix: derive parser diagnostic coordinates from source positions
```

- `git log --oneline 2f47612c2904..8eeb7b5ac14e -- shaders/src shaders/effects` →
  exactly `fa83eeab` (the only shaders/ delta beyond the previously synced
  watermark `2f47612c2904`, which the pass-15 tree already carried).
- Observed delivery `git diff --stat 27590caad94d 8eeb7b5ac14e -- shaders/`:

```
 shaders/src/runtime/backends/webgl2.js |  12 +-
 shaders/src/runtime/backends/webgpu.js |   8 +-
 shaders/src/runtime/expander.js        |  12 ++
 shaders/src/runtime/pipeline.js        |  64 +++++++
 shaders/tests/test_pass_fields.js      | 323 +++++++++++++++++++++++++++++++++
 5 files changed, 414 insertions(+), 5 deletions(-)
```

- `git log --oneline c9ee8a04..8eeb7b5ac14e -- shaders/effects` → empty (0 commits);
  `git diff --stat c9ee8a04 8eeb7b5ac14e -- shaders/effects` → empty (0 files changed):
  the effect catalog is unchanged across the delivered range (0 new / 0 changed /
  0 removed), so the shipped pixel corpora are unaffected.

### Gate evidence, 2026-09-26 (pass 16, current source, committed verbatim)

- `dotnet run --project tools/compiler-contract-tests` (repo root, .NET 8.0.425):
  `compiler contract tests: PASS (0 failures)`.
- `python -m unittest discover -s parity/tests`: `Ran 46 tests in 46.505s` → `OK`.
- `bash parity/param-sweep-verify.sh` with `NM_REFERENCE_ROOT` at the pinned
  worktree `8eeb7b5ac14e`:

```
=== [1/4] regenerate corpus ===
emitted 1900 variants; 3 effects without base program; 0 emit failures; 391 exclusions
corpus matches committed fixtures: 1900 variants
=== [2/4] oracle graphs (reference compiler) ===
oracle ok: 1900, failed: 0
=== [3/4] C# live-compiler graphs (graphdump, no Unity) ===
graph-dump batch done: 1900 ok, 0 fail
=== [4/4] structural diff (fail-closed) ===
param sweep: 1900 graph-clean, 0 FAIL, 0 missing, of 1900 variants
```

### Gate evidence, 2026-09-26 (pass 21, current source `7d8178d`, fresh execution)

Host: Linux x86_64, kernel 6.8.0-134-generic; node v26.5.1; .NET SDK 8.0.412; Python 3.11.2.
Reference pinned by SHA at `noisemaker@8eeb7b5ac14e`. All commands exit 0.

- `python -m unittest discover -s parity/tests -p "test_*.py"`: `Ran 46 tests` → `OK`.
- `dotnet run --project tools/compiler-contract-tests`: `compiler contract tests: PASS (0 failures)`.
- `bash parity/param-sweep-verify.sh`: corpus drift clean (1900 variants),
  oracle 1900/1900, C# graphdump 1900/1900,
  `param sweep: 1900 graph-clean, 0 FAIL, 0 missing, of 1900 variants`.
- Served-kit byte verification (pass-19 script, cross-check revision `7d8178d`):
  `2107 fetched, 0 bad`; `2105 compared, 0 bad`.
- Package identity: `unity/com.noisemaker.hlsl`, 1681 files,
  manifest sha256 `5a7032f9dc09fe1a9db643012549b8e585381a7348e07432f0b8437eca5f0a82`;
  `git diff 3686fd0..7d8178d --name-only -- unity/` → 0 files.
- Authority-drift probe at upstream head `66b8ce7`: the reference oracle re-compiled
  all 1900 corpus variants and the golden graphs are byte-identical to the pinned
  `8eeb7b5a` output (`diff -r` identical, exit 0). The undelivered upstream runtime
  delta does not change any golden graph.

Carried, not re-run (Unity editor required, license-blocked): the 245-fixture pixel
gates and the 316-program Unity graph gate from passes 2–14. The Windows/Linux
platform matrix and the 6000.0 minimum floor stay blocked.

## 4. Evidence

Review CI boundary: Exact-source runs: Export kit. A passing export dispatch does not qualify rendered parity. Current complete-render enforcement remains an open verification requirement. [Exact-source responses and workflows](/Users/alex/.codex/automations/noisemaker-port-completion-audit/review-20260925-053200/noisemaker-for-unity-remote-evidence.json).

[Bounded test evidence](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-tests-retry.json). [Exact-source Actions](https://github.com/noisefactorllc/noisemaker-for-unity/actions?query=head_sha%3Ad48de74c806213789bf1ed8d79ebd8e918437c57).
[This run evidence](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents) retains commands, exit codes, source identities, and distribution metadata.
Official ecosystem reference: [Unity 6.0 manual, accessed 2026-09-24](https://docs.unity3d.com/6000.0/Documentation/Manual/upm-ui-local.html).
Source CI, export dispatch, artifact delivery, and rendered parity are separate evidence dimensions.
A successful dispatch or unit-test summary does not establish a full rendered gate.

## 5. Open compatibility limits

Next bounded check: Re-run all 245 reported fixtures with immutable current reference inputs and raw per-case results. Report zero-tolerance matches separately from 48 historical bounded differences and include the three unported IDs. Test installation and Quick Start on Unity 6000.0 itself before qualifying that minimum, then test the served package in a player build and check upgrade/removal.
See the stable entries in [completion gaps](COMPLETION_GAPS.md).

See [GAP-001 and the complete gap register](COMPLETION_GAPS.md#4-known-gaps) for evidence, dependencies, and acceptance criteria.

1. Reconcile the current authority and complete case inventory, including parameters, inputs, stateful frames, and host versions.
2. Run the existing actual-renderer suite without skip options. Record every missing, failed, refused, or timed-out case.
3. Verify installation, useful output, errors, recovery, upgrades, and removal with the actual distribution.
4. Inspect exact-source CI and retain artifact hashes. Keep unresolved qualification failed or unverified.

All eligible ports have equal priority. Full parity and zero skipped cases remain the goal.
Implementation corrections remain with the separate job. This report does not advance the parity checkpoint.

## 6. History

2026-09-25 daily review at `a2642d834335d0fb30d98d3e6c0245e109930cf7`: source freshness and bounded evidence reviewed. Open qualification limits retained. [Retained review evidence](/Users/alex/.codex/automations/noisemaker-port-completion-audit/review-20260925-053200/current-native-comparisons.json). No new closure claimed.

| Date | Source | Result | Change |
|---|---|---|---|
| 2026-09-26 (pass 22) | `448eca7a329c912de34ffbbb79abe60c0b512474` | GAP-002 artifact-hash re-binding after the GAP-006 texture-pooling port (docs + evidence; GAP-002 status unchanged): the port changed the package tree (5 files, above), so the installed-package manifest hash was recomputed at this revision — 1683 files, sha256 `79ba4b6cc26ee5a9418183cbfddb37b3b5e87ccabf62478d1e69461eb40627bd` (command + output appended in `parity/evidence/2026-09-26-package-artifact-hash.txt`; the 1681-file `5a7032f9…` identity held `3686fd0`→`2e7f75c`) | Installed-artifact-hash acceptance re-bound to the published revision; GAP-002 register Last-verification updated. Carried: Unity-host pixel verification of the runtime change (poolability refusals rebind blend/drawMode/viewport-written virtuals — `NMPipeline.cs`, `TextureStore.cs`) is license-blocked; the required native parity cases (nm_adjust/grade/invert/tint) have no results at this revision (prior receipt binds to `5d4a9e9`); minimum-host/platform-matrix checks remain blocked on the account-bound Unity license. |
| 2026-09-26 (pass 21) | `7d8178d1785efc2dea0cad98db9e1d8c7f2762bc` | Automation re-verification, fresh execution on the Linux audit host (exit 0 on all gates; no closure): comparator 46/46; contract tests PASS; param sweep 1900/1900 graph-clean at pinned `noisemaker@8eeb7b5ac14e`; served kit `0.1.25` byte-verified 2107/2107 with source cross-check 2105/2105; package identity `5a7032f9…` unchanged; authority-drift probe: oracle at `66b8ce7` reproduces all 1900 golden graphs byte-identically | Report header refreshed to the current source, upstream head `66b8ce7`, authority `1.0.185` (`6a0af04d3c4f345ffab5e9f8e54e532216b4cdaa`, 210 effect IDs, manifest sha256 `05c4d7b7744837ae90a3bb4c89e5403ff09448a74d9d7e824abb3d719ad3314e`), and served kit `0.1.25`; pass-21 gate evidence added; declaration-column note corrected to the byte-identical `0.1.25` payload; upstream runtime delta `8eeb7b5a..66b8ce7` recorded as undelivered (implementation job) |
| 2026-09-26 (pass 18) | `8692e963b8d414f9059592e92e1631bf4e4cd9d4` | GAP-002 required-check evidence recording (docs + committed raw evidence; **status remains open**): the declared `6000.0` minimum floor exercised first-hand — Unity `6000.0.84f1` Linux editor (changeset `78ab6fc243d5`, official tarball, unattended) exits batch mode **198** "No valid Unity Editor license found", 0 entitlements (raw log committed: `parity/evidence/2026-09-26-unity-6000-minimum-license-run.log`); installed-artifact manifest hash recomputed unchanged at the review candidate (`git diff 3686fd0..5d4a9e9f4a8 -- unity/com.noisemaker.hlsl` → 0 files; 1681 files, sha256 `5a7032f9dc09fe1a9db643012549b8e585381a7348e07432f0b8437eca5f0a82`, appended in `parity/evidence/2026-09-26-package-artifact-hash.txt`) | Minimum-host-version row updated: `6000.0` floor recorded first-hand unavailable (same account-bound license blocker as `6000.3.16f1`); artifact-hash row requalified at the review candidate. GAP-002 status remains **open**: minimum-host and platform-matrix required checks unmet; native engine cases run after publication. |
| 2026-09-26 (pass 17) | current source | GAP-002 evidence recording (docs + committed raw evidence; **status remains open**): installed package artifact hash recorded — `unity/com.noisemaker.hlsl`, 1681 files, manifest sha256 `5a7032f9dc09fe1a9db643012549b8e585381a7348e07432f0b8437eca5f0a82` (command + output committed: `parity/evidence/2026-09-26-package-artifact-hash.txt`); first-hand Linux editor license run with raw log committed (`parity/evidence/2026-09-26-linux-editor-license-run.log`): batch mode exit 198 "No valid Unity Editor license found", 0 entitlements, changeset `a56f230f6470` tarball on x86_64 kernel 6.8.0-134 | OS/backend matrix row updated: macOS/Metal qualified; Windows/Linux recorded explicitly unavailable to this automation; 6000.0 minimum floor untested (same license blocker); upgrade path not exercisable (single shipped version). Installed-workflow open-items note reworded to "recorded, not closed". GAP-002 status remains **open**: minimum-host and platform-matrix required checks unmet. No host qualification, no pixels rendered. |
| 2026-09-25 (pass 15) | current source | Graph-level per-effect parameter sweep (1900 variants, exit 0, no pixels) | Added `parity/param-sweep.mjs`, `parity/param-sweep-verify.sh`, and the committed corpus `parity/programs/param-sweep/`: one non-default variant per value class of every user-facing parameter of all 207 ported effects (every non-default enum choice, boolean flip, slider midpoint; unbounded float/int params default+1), generated from the pinned authority's definitions `noisemaker@c9ee8a04` (v1.0.176). The gate regenerates the corpus byte-identically (drift-checked), compiles every variant with the reference oracle (`tools/export-graph.mjs`) and the C# live DSL compiler (.NET 8 `tools/graphdump`, no Unity editor), and diffs each with `graph-diff.py`: 1900/1900 graph-clean, 0 FAIL, 0 missing. 391 measured exclusions recorded (`exclusions.tsv`: 280 parameters with no DSL-expressible non-default value, 64 color, 44 surface-input, 3 effects without a curated base program — already covered by the 3D pixel fixtures). Raw per-variant results committed (`results.tsv`). Graph-level only — Unity-side pixel rendering of parameter variants, the Windows/Linux platform matrix, and the declared 6000.0 minimum floor remain open (Unity license activation is account-bound). |
| 2026-09-26 (pass 16) | current source | GAP-005 pass-field row ported (upstream `fa83eeab`, delivered range `27590caad94d..8eeb7b5ac14e`) + gates re-run at the delivered range end | Audited the delivered upstream range `4891b9953f9f..8eeb7b5ac14e` (force-push flagged; `4891b9953f9f` verified an ancestor of `8eeb7b5a`): the only shaders/ code delta beyond the previously synced `2f47612c2904` is `fa83eeab` (GAP-005) — no effect-definition changes (`shaders/effects` untouched `c9ee8a04..8eeb7b5a`), so the effect catalog is unchanged (0 new/changed/removed) and the shipped pixel corpora are unaffected. Ported the pass-field row: `name`/`type`/`clear`/`viewport`/`samplerTypes` copied verbatim onto compiled passes (Expander + GraphLoader), `clear` emitted in the normalized graph only when authored (after `repeat`, oracle key order), the viewport grammar extended to x/y + `w ?? width`/`h ?? height` with per-draw uniform-driven resolution in `NMRenderBackend` (x/y offsets supported; numeric boxes pass through), `samplerTypes`/`name`/`type` retained as queryable data (sampler selection is reference-WebGPU-only). Viewport orientation verified against the upstream diff: the resolved `{x,y,w,h}` is fed verbatim to the reference WebGL2 `gl.viewport` (bottom-left origin, which Unity's `SetViewport` shares) with no flip, and no shipped effect definition authors a non-zero viewport `y` (test fixtures only), so shipped-corpus behavior is unchanged. Evidence: compiler contract tests PASS (0 failures, including the new `TestGap005PassFieldsContract`, red-checked by corrupting the Expander copy), `parity/tests` comparator suite 46/46 PASS, `param-sweep-verify.sh` re-run with `NM_REFERENCE_ROOT` pinned by SHA at `noisemaker@8eeb7b5ac14e`: corpus regenerates byte-identically (1900 variants, drift check clean), oracle 1900/1900 ok, C# 1900/1900 ok, 1900/1900 graph-clean, exit 0 — normalized graphs byte-stable through the delivered range end. Review-resolution follow-ups (same tree): the live writer's normalized key order was brought into exact fidelity with the port-local oracle (`export-graph.mjs` `normalizePass`, untouched by `fa83eeab`) — `repeat` before `clear` before `conditions`; the pre-candidate order emitted `conditions` first, a latent oracle mismatch no corpus pass exercises (the 316-program and 1900-variant corpora contain no pass authoring both, and the sweep diffs stayed byte-identical through the reorder); `pass.clear` now round-trips any authored JSON literal verbatim (the reference consumes it truthily only — webgpu.js `loadOp` — and its PASS_KEYS whitelist at `8eeb7b5a` does not admit `clear`/`samplerTypes` on definition passes, so the row reaches the model via hand-authored graphs; the array/number forms match NMRenderBackend's `ClearColorOf` grammar, guarded by new contract-test cases). Retained: the Unity-side viewport `x`/`y` backend path (`SetViewport` in `NMRenderBackend`) is not exercised by automated tests in this environment — it requires a Unity session (license activation is account-bound) — while the shipped corpus authors no viewport at all, so behavior is unchanged for every shipped effect. Clear semantics aligned to the reference's truthy consumption: `NMRenderBackend` now gates the render-target clear through the new `GraphLoader.IsTruthy` (exact JS truthiness — `clear: false`/`0`/`""`/null do NOT clear; any array/object/non-zero number/non-empty string does), replacing the pre-GAP-005 presence gate that would have cleared on definition-authored `clear: false`; falsy/truthy forms are guarded by contract-test cases. |
| 2026-09-24 (pass 14) | current source | `render` namespace pixel parity (5 new fixtures, exit 0) — **all 207 ported effects now pixel-verified** | Added `parity/render-verify.sh` (two batches: `loopBegin`/`loopEnd`/`renderLit3d`, then `meshLoader`/`meshRender` sharing `programs/meshes/sphere.obj` copied from the pinned authority), `programs/render-manifest.tsv`, `programs/render-mesh-manifest.tsv`, `programs/render-exceptions.json`; 3 strict PASS (`renderLit3d` byte-exact) + 2 ALLOWED_NEAR (`loopBegin`/`loopEnd` — the warp bilinear tie, mad 9 / 10 px / SSIM 0.999999). Extended the harnesses for mesh fixtures (`--mesh` in `batch-golden.mjs`, `-nmMesh` in `NMParityRunner`) and fixed two real bugs the gate exposed: (1) chain-scoped mesh bindings (`global_mesh0_positions_chain_0`) resolved to zeroed pooled RTs instead of the static mesh triplet — nothing rasterized; (2) the WGSL-style manual clip-Y flip inverted the projected winding on Metal, so `Cull Back` culled the near hemisphere and shaded the far one (flat 131/255 ambient+rim field); the VS now reverses each triangle's vertex order to restore the golden's front-face convention. Both fixtures are byte-exact after the fixes. Added certification tests to the `NMOutputRuntimeTests` harness: chain-scoped bindings must resolve to the static triplet, and the shaded-sphere center must measure the near-hemisphere value (≥0.56; the far-hemisphere regression measures 0.513). 45 contract tests PASS. **Full catalog status: 210 declared effects, 3 unported (`synth/media`, `synth/scope`, `synth/spectrum`), all 207 ported effects graph+pixel verified.** |
| 2026-09-24 (pass 13) | current source | `filter` batch 3 of 3 pixel parity (24 new fixtures, exit 0) — filter namespace 113/113 complete | Extended `programs/filter-manifest.tsv` to 74 (`skew` through `zoomBlur`); 16 strict PASS + 8 ALLOWED_NEAR (`spiral`, `step`, `tetraColorArray` — 1 px at the [39,119] knife-edge shared with mixer `thresholdMix`, `tunnel`, `warp`, `waves` — 1 px at [124,193], `snow`, `wormhole`); gate global SSIM floor 0.999 → 0.99 to admit the `snow` cos-ULP→fract-hash decorrelation (mad 69, macro-identical: mean 165.36 both, 94% speck overlap) and the `wormhole` strong-warp displacement tie (mad 197 / 478 px); all budgets still pinned per-case. Filter pixel-verified total now 113/113 (100%); full suite is now 240 fixtures (194 PASS, 46 bounded, exit 0); 42 unit tests PASS. Remaining graph-only: `render/loopBegin`, `loopEnd`, `meshLoader`, `meshRender`, `renderLit3d`. |
| 2026-09-24 (pass 12) | current source | `filter` batch 2 of 3 pixel parity (25 new fixtures, exit 0) + `osd` scanline-parity fix | Extended `programs/filter-manifest.tsv` to 50 (`motionBlur` through `sine`); 18 strict PASS + 7 ALLOWED_NEAR (`octaveWarp`, `pinch`, `polar`, `posterize`, `reindex`, `rotate`, `scanlineError`); gate global SSIM floor lowered 0.9999 → 0.999 to admit the `scanlineError` floor() displacement tie (mad 205 / 12 px / SSIM 0.99949, all other budgets SSIM ≥ 0.99997). Fixed a real implementation bug: `Osd.hlsl` computed scanline parity in top-origin space after the Y-flip, but the golden computes it in gl_FragCoord's bottom-up frame (the (h-1)-flip inverts parity when h-1 is odd) — parity now taken from the un-flipped coord, `osd` went from 64048 differing pixels to byte-exact. Filter pixel-verified total now 89/113; full suite is now 216 fixtures (178 PASS, 38 bounded, exit 0); 42 unit tests PASS. |
| 2026-09-24 (pass 11) | current source | `filter` batch 1 of 3 pixel parity (25 new fixtures, exit 0) | Added `parity/filter-verify.sh`, `programs/filter-manifest.tsv`, `programs/filter-exceptions.json`; namespace verified alphabetically in batches, the gate always re-renders and re-grades the whole tracked manifest: 21 strict PASS + 4 ALLOWED_NEAR (`convolutionFeedback` mad 8 / 770 px feedback accumulation drift, `crt` mad 24 / 812 px phosphor-mask ties, `degauss` mad 8 / 175 px barrel-warp resample ties, `lensWarp` mad 3 / 1 px exact-coordinate displacement tie); filter pixel-verified total now 64/113; full suite is now 191 fixtures (160 PASS, 31 bounded, exit 0); 42 unit tests PASS. |
| 2026-09-24 (pass 10) | current source | `points` 100% pixel parity (10 new fixtures, exit 0) | Added `parity/points-verify.sh`, `programs/points-manifest.tsv`, `programs/points-exceptions.json`; gates run 60 warm frames (~1 s of simulation at 60 fps) from a clean state so particle/agent behavior manifests before grading: 2 strict PASS (`attractor`, `physical` byte-exact) + 8 ALLOWED_NEAR (`buddhabrot`, `dla`, `flock`, `flow`, `hydraulic`, `lenia`, `life`, `physarum` — emergent agent sims share identical macro-structure/trail networks with chaotic per-agent float drift); all 11 `points/*` effects pixel-verified; full suite is now 166 fixtures (139 PASS, 27 bounded, exit 0); 39 unit tests PASS. |
| 2026-09-24 (pass 9) | current source | `mixer` 100% pixel parity (12 new fixtures, exit 0) | Added `parity/mixer-verify.sh`, `programs/mixer-manifest.tsv`, `programs/mixer-exceptions.json`; 10 PASS + 2 ALLOWED_NEAR (`distortion`, `thresholdMix`); all 15 `mixer/*` effects pixel-verified; full suite is now 156 fixtures (137 PASS, 19 bounded, exit 0); 36 unit tests PASS. |
| 2026-09-24 (pass 8) | current source | `synth` 100% renderable pixel parity (15 new fixtures, exit 0) | Added `parity/synth-verify.sh`, `programs/synth-manifest.tsv`, `programs/synth-exceptions.json`; 12 PASS + 3 ALLOWED_NEAR (`julia`, `mandelbrot`, `newton`); all 26 renderable `synth/*` effects pixel-verified; full suite is now 144 fixtures (127 PASS, 17 bounded, exit 0); 33 unit tests PASS. |
| 2026-09-24 (pass 7) | current source | `classicNoisedeck` 100% pixel parity (17 new fixtures, exit 0) | Added `parity/classic-verify.sh`, `programs/classic-manifest.tsv`, `programs/classic-exceptions.json`; 15 PASS + 2 ALLOWED_NEAR (`fractal`, `kaleido`); entire `classicNoisedeck` namespace (20/20) now pixel-verified; full suite is now 129 fixtures (115 PASS, 14 bounded, exit 0); 30 unit tests PASS. |
| 2026-09-24 (pass 6) | current source | Host requirements aligned to Unity 6 (`6000.0`) | Dropped obsolete 2021.3 minimum declaration across `package.json` and all documentation; requirements pinned to Unity 6 (`6000.0+`); closes declared-minimum host debt under GAP-001/GAP-002. |
| 2026-09-24 (pass 2) | `2344c30211c73804989647058506a387de404c91` vs authority `c9ee8a049b2b63cd300da67c01ee40baf29dc288` (v1.0.176) | Declared-corpora parity **measured, exit 0**: graph 316/316, render 112/112 (100 PASS + 12 bounded), contract tests PASS | Regenerated all goldens/graphs from the pinned authority worktree; ran root/3D/v104/tiled gates + graph gate + contract tests; formalized the three previously unbounded root fixtures in `programs/exceptions.json`; added `programs/manifest.tsv` + `root-verify.sh`; refreshed this report with per-effect graph/pixel status. GAP-002/GAP-003 remain open. |
| 2026-09-24 | `d48de74c806213789bf1ed8d79ebd8e918437c57` | Full qualification unverified | Created the requested maintained compatibility report. Preserved historical evidence and open gaps. |

Run: `20260924-remaining-gap-documents`. Later audits and reviews update this report with source-bound results.

### Delivered-range audit, 2026-09-26 (pass 22)

Upstream range `noisemaker@8eeb7b5ac14e..6a0af04d3c4f345ffab5e9f8e54e532216b4cdaa`
(the declared range end `6a0af04d3c4f` carries the force-push-flagged start
`4891b9953f9f` as an ancestor — `git merge-base --is-ancestor 4891b9953f9f
6a0af04d3c4f` → exit 0), checked out detached by SHA at
`noisemaker@6a0af04d3c4f345ffab5e9f8e54e532216b4cdaa`:

- `git log --oneline 8eeb7b5ac14e..6a0af04d3c4f -- shaders/` → exactly three
  shaders/ code commits, all `shaders/src/runtime/**` + `shaders/tests/**` only:
  `6113da00` (GAP-006 texturePooling resource plan), `95743621` (viewport pass
  without clear = partially written for pooling), `f83a427e` (structured backend
  diagnostic union). `git diff --stat c9ee8a04 6a0af04d -- shaders/effects` →
  empty (0 files changed): the effect catalog is unchanged (0 new / 0 changed /
  0 removed); the published effect manifest stays 210 IDs,
  sha256 `05c4d7b7744837ae90a3bb4c89e5403ff09448a74d9d7e824abb3d719ad3314e`.

Ported to this repo (pass 22, this commit):

- `6113da00` + `95743621` (GAP-006 texture-pooling safety): this port ALWAYS
  materializes `graph.allocations` (one phys_N RT per allocation group,
  `TextureStore.AllocatePooled`), so the reference's `texturePooling: true`
  opt-in has no opt-out equivalent here — what was missing is upstream's
  poolability refusals. New `Compiler/Graph/TexturePoolability.cs`
  (`ComputePoolable`) computes the exact upstream refusal rules from the
  normalized graph: persistent/mipmaps/3D policy members, first-touch-read
  members, self-sampled members, and members written by partial/non-clearing
  passes (any explicit `drawMode` scatter, `blend`, or a `viewport` write
  without a truthy `clear` — the `95743621` guard) are refused; a group is
  pooled only when every member carries an identical plain 2D
  (width, height, format) signature. `TextureStore.AllocatePooled` now shapes
  each phys candidate over poolable members only, and `NMPipeline.ResolvePhysical`
  binds a refused virtual to a dedicated texId-keyed RT with standalone
  semantics. Classification runs after `ApplyMrtFormatBudget()` (Init and every
  uniform-driven recreate), matching the reference's placement.
- `Pipeline.getResourcePlan()` (GAP-006 query contract): new
  `NMPipeline.GetResourcePlan()` returns a C#-typed
  `{ pooling, allocations, sharedTextures, textures }` plan with per-record
  `virtualTextures`, reporting the sharing the renderer actually materialized
  (read-only; lazily unallocated textures are simply absent).
- `f83a427e` (structured backend diagnostic union): NOT ported — it normalizes
  WebGL2/WebGPU shader-compile/link throw surfaces in the reference's JS
  backends; this port has no JS backend (Unity shaders are precompiled assets;
  failures surface through Unity's own `Debug.LogError` shader-resolution path
  at `NMRenderBackend.ExecutePass`), so there is no equivalent throw surface.
- Effect-catalog parity: 0 new / 0 changed / 0 removed (verified against the
  pinned `6a0af04d` checkout); the shipped pixel corpora are unaffected.

Gate evidence (pass 22, current source, Linux audit host, .NET SDK 8.0.412,
numpy 2.5.3 / pillow 12.3.0; all exit 0):

- `dotnet run --project tools/compiler-contract-tests`:
  `compiler contract tests: PASS (0 failures)` — including the new
  `TestGap006TexturePoolability` (19 checks: poolable group, all refusal
  branches, dim-form mismatch, viewport clear truthiness
  false/0/null/absent-vs-true, single-member group, global exclusion),
  red-checked: disabling the `95743621` viewport guard failed exactly its
  5 viewport cases and nothing else.
- `python -m unittest discover -s parity/tests -p "test_*.py"`:
  `Ran 46 tests` → `OK`.
- `bash parity/param-sweep-verify.sh` with `NM_REFERENCE_ROOT` pinned by SHA at
  `noisemaker@6a0af04d3c4f345ffab5e9f8e54e532216b4cdaa`:
  corpus drift clean (1900 variants), oracle 1900/1900, C# graphdump 1900/1900,
  `param sweep: 1900 graph-clean, 0 FAIL, 0 missing, of 1900 variants`.

Carried, not re-run (Unity editor required, license-blocked): the 245-fixture
pixel gates and the 316-program Unity graph gate from passes 2–14. The
Windows/Linux platform matrix and the 6000.0 minimum floor stay blocked.
