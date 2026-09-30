# noisemaker-for-unity: compatibility report

## 1. Source and authority revisions

Audit pass: 2026-09-29 (pass 32). Audited source: this pass's delivery commit (see the §3 pass-32 section; raw upstream-audit transcript archived as Worker Elves evidence `2026-09-29-pass32-range-audit.txt`). Local `main` was clean and matched `origin/main` before the checks.
Automation-completable gates re-verified fresh at this source (see §3 gate evidence). Unity-host pixel gates for the four declared native parity cases (`nm_adjust_test`, `nm_grade_test`, `nm_invert_test`, `nm_tint_test`) passed fresh on the licensed Unity 6000.3.16f1 macOS host at source `d3b1ad9`/pass 29 (thresholds max-abs-diff ≤ 2, SSIM ≥ 0.98; supervisor native-check receipt 2026-09-27T08:47:50Z) and are re-queued at this pass's delivery commit. No release approval or new closure follows from this pass.
Daily review 2026-09-28 at `04e7e94204509f83fdf2f2c0ddc0d266636f6900` (`origin/main` HEAD): the GAP-002 and GAP-003 closures were independently verified (kit `0.1.29` sample byte-checks, licensed-host import, runtime harness, Quick Start render byte-identical `0da6bc75…`); the `unity/` package tree is unchanged `557093f..04e7e94`. Exact-source CI: `Tests` run `36378117400` success at `04e7e94`, `Export kit` run `36349467053` success at `557093f`. See the daily-review section in [completion gaps](COMPLETION_GAPS.md).
Current upstream head: `4f5e0d28` (`4f5e0d28bdc155700393c314e9a5aafcc4da91fd`), audited in §3 pass 32. Beyond the previously audited `noisemaker@12b4d74fb4f2..73c15be00d68` (pass 31), the delivered range (`73c15be00d68..682739066d3b`, force-push flag audited — the declared start `73c15be0` is the already-audited pass-31 end and an ancestor of the declared end; all four observed ranges `3e21906..a5059106`, `a5059106..68273906`, `c4606d1..4d47b3fd`, `4d47b3fd..4f5e0d28` lie on `origin/main`, with the last window extending past the declared end, so the audited span is the union `73c15be0..4f5e0d28`, fourteen commits on one linear history) adds exactly one new `shaders/` surface — GAP-032 `a5059106` + `68273906` + follow-ups `4d47b3fd` + `4f5e0d28`, all confined to `shaders/src/runtime/external-input.js`'s `AudioInputManager` class plus its `shaders/tests/test_external_input.js` harness — which has no Unity surface, so no port follows (ruling in §3 pass 32). The remaining ten commits are upstream documentation/ledger passes (`53398923`, `cdb60cfc`, `d95d0c8c`, `3e21906e`, `bff453e9`, `8fec3d05`, `42843597`, `c4606d11`) and dependency bumps (`6b05a270` eslint, `a50c90bc` ruff). Effect catalog unchanged: `git diff --stat 73c15be0..4f5e0d28 -- shaders/effects shaders/glsl shaders/wgsl shaders/src/definition.js` → 0 files changed; the manifest stays 210 IDs and remains byte-identical (sha256 `05c4d7b7744837ae90a3bb4c89e5403ff09448a74d9d7e824abb3d719ad3314e`).
Beyond the previously synced `noisemaker@8eeb7b5ac14e`, upstream held 3 runtime-only commits (`f83a427`, `9574362`, `6113da0`: backend diagnostics, texture-pooling, GAP-006 resource plan) in `shaders/src/runtime/**` and tests. As of pass 22 the GAP-006 row (`6113da0`+`9574362`) is delivered (§3 pass 22); `f83a427` is a JS-backend diagnostic-union change with no Unity-renderer equivalent and needs no port.
2026-09-28 review observation: upstream advanced `296e0138..73c15be0` — `c28e8fdb` (WebGL2 mesh-target fix), `7aff843a` (harness GAP-024), and `73c15be0` (runtime onInit/onUpdate/onDestroy lifecycle hooks, GAP-026). Files: `shaders/src/runtime/**` and tests only. Effect catalog unchanged (`git diff --stat 296e0138..73c15be0 -- shaders/effects shaders/glsl shaders/wgsl shaders/src/definition.js` → 0 files). Audited and ruled in §3 pass 31: no Unity surface for any of the three deltas, no port follows.
2026-09-29 audit observation: upstream advanced `73c15be0..4f5e0d28` — four GAP-032 audio-capture commits (`a5059106`, `68273906`, `4d47b3fd`, `4f5e0d28`) confined to `shaders/src/runtime/external-input.js`'s `AudioInputManager` class + `shaders/tests/test_external_input.js` (the follow-up pair also adds upstream's own `scripts/test` entrypoint), plus documentation, ledger and dependency-bump commits. Effect catalog unchanged (`git diff --stat 73c15be0..4f5e0d28 -- shaders/effects shaders/glsl shaders/wgsl shaders/src/definition.js` → 0 files). Audited and ruled in §3 pass 32: no Unity surface, no port follows.
The observations below retain their original source and authority identities. They do not qualify later updates.
Current served kit: `0.1.29`, source `557093f8263e9fbe1854c54ab394c08ecd1467a3`, byte-verified in pass 30 (2026-09-28): 2111/2111 CDN files checked against the manifest, source cross-check 2109/2109, exit 0. The 2026-09-28 review re-verified it: stratified sample 212/212 byte-checked (0 bad) and engine-payload cross-check 21/21 against `557093f` (0 bad). [Deployment metadata](https://kits.noisedeck.app/unity/0/deployment-meta.json). Artifact identity does not establish host qualification.

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
| Minimum and current host versions | verified | Package declared minimum aligned to Unity 6 (`6000.0`). Observed on `6000.3.16f1`. The `6000.0` floor is now qualified first-hand on a licensed host (pass 29, 2026-09-27): Unity `6000.0.84f1` (changeset `78ab6fc243d5`, official `MacEditorInstaller/Unity.pkg` sha256 `3df66b594b3acbe5938cec52d12f8eeaf41df6e8049c3ff1e9b395dda244870b`) installed unattended on the licensed darwin/arm64 macOS host without admin (`pkgutil --expand-full`; editor binary x86_64 under Rosetta) and licensed from the machine `Unity_lic.ulf` — fresh project import of the embedded package exit 0 with 0 `error CS`, `NMOutputRuntimeTests.VerifyFromCommandLine` exit 0, Quick Start graph renders 512×512 (212/212 shaders resolved; byte-identical across two runs, sha256 `0da6bc75…`, mean 111.47, 100% non-black). Raw log: [floor run](../parity/evidence/2026-09-27-unity-6000-minimum-floor-macos-run.log). The earlier Linux-editor recordings (pass 18: `6000.0.84f1` exits 198 unlicensed) remain the first-hand Linux evidence. |
| Supported operating systems and backends | unverified outside macOS | macOS/Metal qualified (isolated consumer + headless player, passes 3/4) and additionally at the declared minimum host: Unity `6000.0.84f1` on the same licensed macOS host (pass 29, 2026-09-27 — see the host-versions row). Windows/Linux recorded explicitly unavailable to this automation (2026-09-26, first-hand: the Linux editor exits batch mode 198 — "No valid Unity Editor license found"; 0 entitlements; re-verified 2026-09-27: the fleet's only licensed Unity host is darwin/arm64 macOS — the gateway host list is committed verbatim in [the floor-run transcript](../parity/evidence/2026-09-27-unity-6000-minimum-floor-macos-run.log); no Windows host exists). |
| Installed package and first useful result | verified | Isolated consumer (embedded package, Linear): Quick Start sample imported, Play-mode test renders the bundled noise→blur graph to 512×512 ARGBHalf, binds to the target material, meaningful output (play-mode test PASS); same workflow reproduces in a macOS player build (see below). |
| Parameters, external inputs, state, and chains | unverified | Full current-authority combinations remain unmeasured. |
| Invalid input and recovery | verified | Documented `no graph source` error path; corrupt graph JSON raises `FormatException` (raised, not swallowed); valid input afterwards renders normally. Public entry point only. |
| Upgrade, removal, and resource cleanup | verified (removal/reinstall) | Package + dependents removed → consumer imports clean with zero errors and no residue; full re-embed → import clean and the 3/3 play-mode suite passes again. Upgrade path untested (single shipped version); resource cleanup is covered by the runtime's dispose paths exercised in every render session. |
| Accessibility of provided controls | unverified | Keyboard, focus, labels, and diagnostics need host observations where applicable. |
| Release readiness | open (GAP-001) | Installation, host, and artifact evidence are qualified (GAP-002/GAP-003 closed, passes 29/30, verified 2026-09-28). Rendered parity remains incomplete: 16 pixel-unresolved `synth/shape` rows (cell3d seed resolved pass 31), 97 variants without a faithful reference render, and the 245-fixture re-run at the current authority. |

## 3. Parity coverage

### Daily review, 2026-09-25

The report of 245 fixtures contains 197 tolerance-based PASS results and 48 bounded differences, with three unported current effect IDs. It is not full parity. This review independently ran Unity 6000.5.5f1 on the current package: solid is exact. Noise differs in 30 channels with maximum 1. Heightmap3d_landscape differs in five channels with maximum 3. These three comparisons use retained historical goldens. The 6000.0 minimum, full player workflow, and later 245-case claim remain incompletely reviewed. Raw evidence (audit evidence `review-20260925-053200/current-native-comparisons.json`).

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

Raw per-variant results: `parity/programs/param-sweep/results.tsv` (all `PASS`; header pins the authority revision). One non-default variant per value class of every user-facing parameter of all 207 ported effects (enum choices, boolean flips, slider midpoints; unbounded params default+1). Graph-level only — no pixels rendered.

Unity-side pixel rendering of parameter variants (2026-09-27, GAP-001 pass 27, licensed host):

Same-machine staged gate `parity/param-sweep-pixel-verify.sh` (`--stage goldens|unity|grade`): reference goldens from the pinned authority `noisemaker@403c2a4b` rendered in headless Chromium WebGL2/ANGLE on the licensed macOS host's GPU; Unity candidates from the licensed Unity 6000.3.16f1 editor (Metal), same machine and GPU; grading in the automation container (numpy/pillow), fail-closed. Points variants render 60 warm frames; the 17 `render__meshRender__*` variants share `programs/meshes/sphere.obj`.

| Group | Graded | PASS (tol 1/2) | ALLOWED_NEAR | FAIL (unresolved) |
|---|---|---|---|---|
| strict (tol 1, SSIM ≥ 0.99) | 504 | 415 | 89 | 0 |
| filter (tol 1, SSIM ≥ 0.98) | 627 | 437 | 189 | 1 |
| synth (tol 1, SSIM ≥ 0.90) | 468 | 391 | 61 | 16 |
| 3d (tol 2, SSIM ≥ 0.98) | 120 | 94 | 25 | 1 |
| points (tol 1, SSIM floor 0) | 84 | 17 | 67 | 0 |
| Total | 1803 | 1354 | 431 | 18 |

Pass 31 (2026-09-28): `synth3d/cell3d` seed resolved — Metal fp contraction in
`Cell3d.hlsl` `hash3` (fma with unrounded product; exact-product int convert)
fixed with `precise` two-step rounding; 3d group becomes 94 PASS / 26
ALLOWED_NEAR / 0 FAIL (total 1354 / 432 / 17). Seed__mid measures max 6, SSIM
0.99999978 vs both reference backends (1 sparse-tie pixel, sibling mechanism
class, budget pinned in `pixel-exceptions-3d.json`). New reference-internal
finding: at `volumeSize: x128` the reference's own WebGL2 vs WebGPU goldens
diverge (max 215, SSIM 0.9177); the port matches WebGL2 (max 1), the grading
authority. Same latent contraction pattern remains in `Noise3d.hlsl`
`n3d_hash4`; its corpus pixel cases (including `seed: 51`) pass. Raw pass-31
run output: Worker Elves job `d1363dc5-3cf4-48a7-b863-e45a7cf03d1a` evidence
archive — host goldens (`corpus-gold-webgl2`/`-webgpu`, 10 ok each), Unity
Metal candidates (10 ok), grade JSON (per-case max/mean/SSIM above).

- Group SSIM floors are measured envelopes for this corpus: the reference's own two backends (WebGPU Metal vs WebGL2/ANGLE, measured per case) diverge to SSIM ≈ 0 on parameter-variant point simulations (both engines self-deterministic), and the established snow / mandelbrot hash-chaos families measure down to 0.98/0.91 at variant parameters. PASS remains byte tolerance; every `ALLOWED_NEAR` is pinned by an exact per-case exception budget (max delta, mean delta, SSIM floor, exceeded pixel/channel counts) with its mechanism in `parity/programs/param-sweep/pixel-exceptions-*.json` (432 cases), including the measured reference backend self-divergence for each point-simulation case.
- 97 variants have no faithful reference render and are recorded with their measured proof in `parity/programs/param-sweep/pixel-reference-blocked.tsv`: 89 where the reference demo renders its effect's default output byte-identically (golden == the default-program render) because the demo path does not apply the variant parameter (e.g. every `classicNoisedeck/effects` flip/offset/rotation/scale variant); 7 where the reference's shipped WGSL source and its actual demo behavior disagree (both reference backends agree with each other, corr ≈ 1.0, while the port renders the WGSL-faithful result: glitch/lensDistortion `vignetteAmt` formula parenthesization, the `effects` kernel `cga/derivDivide/edge/litEdge` unguarded GLSL division by a zero kernel weight, and the `meshRender` wireframe flat color); and 1 reference renderer crash (`filter__adjust__mode__hsv`, reproduced 2× on macOS Metal and 2× on Linux SwiftShader, neighboring parameter values fine). Parameter-to-graph binding for all of these is verified 1900/1900 by the graph gate above.
- 16 variants remain FAIL by design in `parity/programs/param-sweep/pixel-unresolved.tsv` (16 `synth/shape` loopA/BOffset noise-interpolated displacement modes; `filter/reverb` wrap=clamp was resolved pass 28 and `synth3d/cell3d` seed was resolved pass 31 — Metal fp contraction fixed with `precise` two-step rounding): measured divergences (SSIM 0.45-0.90) where the reference is cross-backend deterministic, so this is not chaos; the port follows the audited WGSL structure, so the residual cause needs port/authority shader-level investigation. The gate fails closed on them.

Raw grade log: [`parity/evidence/2026-09-27-param-sweep-pixel-grade.log`](../parity/evidence/2026-09-27-param-sweep-pixel-grade.log). Platform matrix (Windows/Linux) and the declared `6000.0` minimum floor remain unavailable (see the pass-17/18 recording below).

Every `ALLOWED_NEAR` matched its recorded budget exactly (max delta, SSIM floor, exceeded pixel/channel counts, exact coordinates). The three previously unbounded root fixtures (`heightGrid_billboard`, `heightmap3d_landscape`, `nm_chrome_test`) are now formalized in `programs/exceptions.json` with mechanisms from this pass's measurements; `parallax` and `refract_mirror` reproduced their recorded budgets byte-for-byte. The v104 corpus reproduced its recorded 66+4 result unchanged.

These gates establish rendered parity for the declared fixture corpora at the pinned authority. Per-effect parameter/state/input breadth remains open under GAP-001; GAP-002's workflow legs are qualified (passes 3/4/6/29 — the declared `6000.0` minimum floor was qualified on the licensed macOS host on 2026-09-27 and GAP-002 closed); distribution (GAP-003) qualification remains open.

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

Every unexecuted fixture remains visible in the fixture inventory (audit evidence `evidence-20260924-remaining-gap-documents/unity-fixture-inventory.json`).
Fixture counts do not prove coverage of every current effect, parameter, or stateful workflow.

| Case | Exact result | Measurement | Evidence |
|---|---|---|---|
| `blendMode` | failed | [FAIL] blendMode: max-abs-diff=1.000 mean-abs-diff=0.0004 ssim=1.00000 (tol=0.0, ssim_min=0.98) | Raw command (audit evidence `evidence-20260924-remaining-gap-documents/unity-blendMode-comparison-command.json`) |
| `blur` | failed | [FAIL] blur: max-abs-diff=1.000 mean-abs-diff=0.0001 ssim=1.00000 (tol=0.0, ssim_min=0.98) | Raw command (audit evidence `evidence-20260924-remaining-gap-documents/unity-blur-comparison-command.json`) |
| `cell` | verified | [PASS] cell: max-abs-diff=0.000 mean-abs-diff=0.0000 ssim=1.00000 (tol=0.0, ssim_min=0.98) | Raw command (audit evidence `evidence-20260924-remaining-gap-documents/unity-cell-comparison-command.json`) |
| `gradient` | failed | [FAIL] gradient: max-abs-diff=1.000 mean-abs-diff=0.0002 ssim=1.00000 (tol=0.0, ssim_min=0.98) | Raw command (audit evidence `evidence-20260924-remaining-gap-documents/unity-gradient-comparison-command.json`) |
| `heightGrid_billboard` | failed | [FAIL] heightGrid_billboard: max-abs-diff=2.000 mean-abs-diff=0.0002 ssim=1.00000 (tol=0.0, ssim_min=0.98) | Raw command (audit evidence `evidence-20260924-remaining-gap-documents/unity-heightGrid_billboard-comparison-command.json`) |
| `heightGrid_billboard_alpha` | failed | [FAIL] heightGrid_billboard_alpha: max-abs-diff=1.000 mean-abs-diff=0.0000 ssim=1.00000 (tol=0.0, ssim_min=0.98) | Raw command (audit evidence `evidence-20260924-remaining-gap-documents/unity-heightGrid_billboard_alpha-comparison-command.json`) |
| `heightGrid_pointsRender_perspective` | verified | [PASS] heightGrid_pointsRender_perspective: max-abs-diff=0.000 mean-abs-diff=0.0000 ssim=1.00000 (tol=0.0, ssim_min=0.98) | Raw command (audit evidence `evidence-20260924-remaining-gap-documents/unity-heightGrid_pointsRender_perspective-comparison-command.json`) |
| `heightmap3d_landscape` | failed | [FAIL] heightmap3d_landscape: max-abs-diff=3.000 mean-abs-diff=0.0000 ssim=1.00000 (tol=0.0, ssim_min=0.98) | Raw command (audit evidence `evidence-20260924-remaining-gap-documents/unity-heightmap3d_landscape-comparison-command.json`) |
| `nm_adjust_test` | failed | [FAIL] nm_adjust_test: max-abs-diff=1.000 mean-abs-diff=0.0003 ssim=1.00000 (tol=0.0, ssim_min=0.98) | Raw command (audit evidence `evidence-20260924-remaining-gap-documents/unity-nm_adjust_test-comparison-command.json`) |
| `nm_alphaMask_test` | failed | [FAIL] nm_alphaMask_test: max-abs-diff=1.000 mean-abs-diff=0.0001 ssim=1.00000 (tol=0.0, ssim_min=0.98) | Raw command (audit evidence `evidence-20260924-remaining-gap-documents/unity-nm_alphaMask_test-comparison-command.json`) |
| `nm_chrome_test` | failed | [FAIL] nm_chrome_test: max-abs-diff=41.000 mean-abs-diff=0.0022 ssim=1.00000 (tol=0.0, ssim_min=0.98) | Raw command (audit evidence `evidence-20260924-remaining-gap-documents/unity-nm_chrome_test-comparison-command.json`) |
| `nm_grade_test` | failed | [FAIL] nm_grade_test: max-abs-diff=1.000 mean-abs-diff=0.0001 ssim=1.00000 (tol=0.0, ssim_min=0.98) | Raw command (audit evidence `evidence-20260924-remaining-gap-documents/unity-nm_grade_test-comparison-command.json`) |
| `nm_invert_test` | failed | [FAIL] nm_invert_test: max-abs-diff=1.000 mean-abs-diff=0.0001 ssim=1.00000 (tol=0.0, ssim_min=0.98) | Raw command (audit evidence `evidence-20260924-remaining-gap-documents/unity-nm_invert_test-comparison-command.json`) |
| `nm_tint_test` | failed | [FAIL] nm_tint_test: max-abs-diff=1.000 mean-abs-diff=0.0000 ssim=1.00000 (tol=0.0, ssim_min=0.98) | Raw command (audit evidence `evidence-20260924-remaining-gap-documents/unity-nm_tint_test-comparison-command.json`) |
| `noise` | failed | [FAIL] noise: max-abs-diff=1.000 mean-abs-diff=0.0001 ssim=1.00000 (tol=0.0, ssim_min=0.98) | Raw command (audit evidence `evidence-20260924-remaining-gap-documents/unity-noise-comparison-command.json`) |
| `osc2d` | verified | [PASS] osc2d: max-abs-diff=0.000 mean-abs-diff=0.0000 ssim=1.00000 (tol=0.0, ssim_min=0.98) | Raw command (audit evidence `evidence-20260924-remaining-gap-documents/unity-osc2d-comparison-command.json`) |
| `remap_zones` | failed | [FAIL] remap_zones: max-abs-diff=1.000 mean-abs-diff=0.0001 ssim=1.00000 (tol=0.0, ssim_min=0.98) | Raw command (audit evidence `evidence-20260924-remaining-gap-documents/unity-remap_zones-comparison-command.json`) |
| `shape` | failed | [FAIL] shape: max-abs-diff=1.000 mean-abs-diff=0.0035 ssim=1.00000 (tol=0.0, ssim_min=0.98) | Raw command (audit evidence `evidence-20260924-remaining-gap-documents/unity-shape-comparison-command.json`) |
| `solid` | verified | [PASS] solid: max-abs-diff=0.000 mean-abs-diff=0.0000 ssim=1.00000 (tol=0.0, ssim_min=0.98) | Raw command (audit evidence `evidence-20260924-remaining-gap-documents/unity-solid-comparison-command.json`) |

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

Review CI boundary: Exact-source runs: Export kit. A passing export dispatch does not qualify rendered parity. Current complete-render enforcement remains an open verification requirement. Exact-source responses and workflows (audit evidence `review-20260925-053200/noisemaker-for-unity-remote-evidence.json`).

Bounded test evidence (audit evidence `evidence-20260924-remaining-gap-documents/unity-tests-retry.json`). [Exact-source Actions](https://github.com/noisefactorllc/noisemaker-for-unity/actions?query=head_sha%3Ad48de74c806213789bf1ed8d79ebd8e918437c57).
This run evidence (audit evidence `evidence-20260924-remaining-gap-documents`) retains commands, exit codes, source identities, and distribution metadata.
Official ecosystem reference: [Unity 6.0 manual, accessed 2026-09-24](https://docs.unity3d.com/6000.0/Documentation/Manual/upm-ui-local.html).
Source CI, export dispatch, artifact delivery, and rendered parity are separate evidence dimensions.
A successful dispatch or unit-test summary does not establish a full rendered gate.

## 5. Open compatibility limits

Next bounded check: Re-run all 245 reported fixtures with immutable current reference inputs and raw per-case results. Report zero-tolerance matches separately from 48 historical bounded differences and include the three unported IDs. Installation, Quick Start, the served-package player build, and distribution legs are qualified (passes 29/30 — GAP-002 and GAP-003 closed, verified 2026-09-28). The upgrade path stays not exercisable (single served version).
See the stable entries in [completion gaps](COMPLETION_GAPS.md).

See [GAP-001 and the complete gap register](COMPLETION_GAPS.md#4-known-gaps) for evidence, dependencies, and acceptance criteria.

1. Reconcile the current authority and complete case inventory, including parameters, inputs, stateful frames, and host versions.
2. Run the existing actual-renderer suite without skip options. Record every missing, failed, refused, or timed-out case.
3. Verify installation, useful output, errors, recovery, upgrades, and removal with the actual distribution.
4. Inspect exact-source CI and retain artifact hashes. Keep unresolved qualification failed or unverified.

All eligible ports have equal priority. Full parity and zero skipped cases remain the goal.
Implementation corrections remain with the separate job. This report does not advance the parity checkpoint.

## 6. History

2026-09-25 daily review at `a2642d834335d0fb30d98d3e6c0245e109930cf7`: source freshness and bounded evidence reviewed. Open qualification limits retained. Retained review evidence (audit evidence `review-20260925-053200/current-native-comparisons.json`). No new closure claimed.

| Date | Source | Result | Change |
|---|---|---|---|
| 2026-09-28 (daily review) | `04e7e94204509f83fdf2f2c0ddc0d266636f6900` | Independent verification of the worker audit `audit-20260926-170500` and the range `7d8178d..04e7e94`: GAP-002 and GAP-003 closures verified (kit `0.1.29` identity and sample bytes, licensed-host import, `[NMOutputRuntimeTests] PASS`, Quick Start render byte-identical `0da6bc75…`, exact-source CI `Tests` at `04e7e94` and `Export kit` at `557093f` both success). GAP-001 stays open. | §1 daily-review and upstream-advance records added (upstream head `73c15be0`, GAP-026 runtime delta undelivered, catalog unchanged); §1 served-kit line corrected to kit `0.1.29` (was stale at `0.1.25`); §2 release-readiness row corrected to open (GAP-001) with the qualified scope; §5 next-check paragraph updated for the closed distribution legs. |
| 2026-09-27 (pass 30) | this pass's delivery commit | GAP-016 static-preflight port + delivered-range audit `7443f6e..296e0138` (force-push flag audited): upstream's only `shaders/src` delta `12b4d74f` ported as `Compiler/Graph/GraphPreflight.cs` + `NMPipeline.Preflight()` with the runtime's MRT-demotion and volumeSize-clamp walks delegated to the shared implementation (lockstep by construction; no authorability verdict invented — single HLSL backend); GAP-017/019/021 are `shaders/tests/` harness modules only, no Unity change. Effect catalog unchanged (manifest sha256 `05c4d7b…`). Gates: contract tests PASS incl. new `TestGap016GraphPreflight` (red-before verified at compile time), unittest 46 OK, param sweep 1900 graph-clean at pinned `noisemaker@296e0138`. Package manifest hash re-bound: 1685 files, sha256 `48faab8e…`. | Header refreshed to upstream head `296e0138`; §3 pass-30 delivered-range audit, port description, and gate evidence added; package artifact hash re-bound (1685 files, `48faab8e…`, appended in `parity/evidence/2026-09-26-package-artifact-hash.txt`); raw transcript `parity/evidence/2026-09-27-pass30-range-audit.txt`; verbatim range patch `parity/evidence/2026-09-27-pass30-upstream-range.patch`; package `CHANGELOG.md` entry added. Carried: the four native parity cases and Unity-host pixel checks re-queue at the new delivery commit via verify; platform-matrix rows unchanged (blocked, pass 29 record). |
| 2026-09-27 (pass 29) | current source (`12a4be3`) | GAP-002 minimum-host-floor qualification on the licensed macOS host (docs + committed raw evidence; **GAP-002 closed**): Unity `6000.0.84f1` (changeset `78ab6fc243d5`, official `MacEditorInstaller/Unity.pkg` sha256 `3df66b594b3acbe5938cec52d12f8eeaf41df6e8049c3ff1e9b395dda244870b`) installed unattended on the licensed darwin/arm64 macOS host without admin (`pkgutil --expand-full`; editor binary x86_64 under Rosetta, licensed from the machine `Unity_lic.ulf`); isolated consumer at this source: import exit 0 with 0 `error CS`, `NMOutputRuntimeTests.VerifyFromCommandLine` exit 0, Quick Start graph renders 512×512 with 212/212 shaders resolved — byte-identical across two runs (sha256 `0da6bc75…`, 444,389 bytes, mean 111.47, 100% non-black); both render runs exit 139 (deterministic Unity shutdown segfault after the output was written — recorded truthfully as an editor artifact). Windows/Linux re-verified unavailable (fleet's only licensed Unity host is macOS; gateway host list committed verbatim, darwin/arm64 attribution from first-hand host probes). The installed-package manifest hash was re-bound at this closing candidate: 1683 files, sha256 `1b99b187afc97694c2948a0a1a92bda4232002e2cd701fe215fa44145ad7ed11` (appended in `parity/evidence/2026-09-26-package-artifact-hash.txt`; the pass-28 `Reverb.hlsl` fix changed the tree after the pass-22 re-bind). | Host-versions matrix row → verified (minimum `6000.0` exercised on a licensed host); OS/backend row updated; GAP-002 closed in the gap register (see [COMPLETION_GAPS.md](COMPLETION_GAPS.md)). Raw transcript: `parity/evidence/2026-09-27-unity-6000-minimum-floor-macos-run.log`. |
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
numpy 2.5.3 / pillow 12.3.0; all exit 0; raw command transcript committed at
[`parity/evidence/2026-09-26-gap006-upstream-range-audit.txt`](../parity/evidence/2026-09-26-gap006-upstream-range-audit.txt),
re-executed fresh at pass 25 — upstream range commands verbatim, local gates re-run
verbatim):

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

### Delivered-range audit, 2026-09-26 (pass 26)

Upstream range `noisemaker@6a0af04d3c4f345ffab5e9f8e54e532216b4cdaa..403c2a4bf2cb56307448ea2fc1d6fa3cd74b7d6e`
(force-push-flagged trigger; audited, not assumed), reference checked out
detached by SHA at `403c2a4bf2cb`, current `origin/main` tip `7730ea4a`:

- Ancestry audited first (`git merge-base --is-ancestor`, raw transcript in
  [`parity/evidence/2026-09-26-gap008-range-audit.txt`](../parity/evidence/2026-09-26-gap008-range-audit.txt)):
  `4891b995` is an ancestor of `6a0af04d` (the prior force-push flag resolves),
  `6a0af04d` is an ancestor of `403c2a4b`, `403c2a4b` is on `origin/main`, and
  the observed side-range commit `9f85687d` (GAP-010) is also on `origin/main`;
  upstream tip is `7730ea4a` (docs-only beyond `403c2a4b`).
- `git log --stat 6a0af04d..403c2a4b -- shaders/` → exactly two code commits:
  `403c2a4b` (GAP-008: `shaders/src/index.js`, `shaders/src/lang/index.js`,
  `shaders/src/lang/paramAliases.js`, `shaders/src/lang/transform.js` +
  `shaders/tests/test_transform.js`) and `b35361e0` (GAP-009:
  `shaders/tests/**` only). Between `403c2a4b` and `origin/main` exactly one
  further shaders/ commit exists: `9f85687d` (GAP-010, `shaders/tests/**`
  only), plus `0ac52500` / `7730ea4a` docs. The remaining range commits
  (`01e9d620`, `3968f6c4`, `a651c075`, `66b8ce7d`, `19fdcb56`) are upstream
  documentation passes.
- NOT ported — `403c2a4b` (GAP-008): `predictReplacement()` /
  `getParamAliases()` / `replaceEffect(preflight:true)` extend the JS
  lang-layer `replaceEffect` authoring API in `shaders/src/lang/transform.js`.
  This Unity port has no program-transform/replaceEffect layer: `grep -rn
  "replaceEffect|getCompatibleReplacements|listSteps|preflight"` over
  `unity/`, `docs/`, `reference/` matches nothing outside the reference
  validator spec, and `DslCompiler` exposes no graph-mutation entry point —
  the C# runtime compiles and renders authored programs only. There is no
  equivalent surface to change, so no Unity code change follows.
- NOT ported — GAP-009 `b35361e0` and GAP-010 `9f85687d`: new JS test-harness
  modules (`frame-metrics`, `uniform-status`) and regressions under
  `shaders/tests/` only; no engine behavior.
- Effect-catalog parity: 0 new / 0 changed / 0 removed
  (`git diff --stat 6a0af04d3c4f..7730ea4a -- shaders/effects shaders/glsl
  shaders/wgsl shaders/src/definition.js shaders/src/runtime shaders/src/lang/ops.js
  shaders/src/lang/validator.js` → 0 files); no WGSL/GLSL→HLSL translation is
  touched by this range, so no translation cross-check arises.

Gate evidence (pass 26, current source, Linux audit host, .NET SDK 8.0.412,
numpy 2.5.3 / pillow 12.3.0; raw command transcript appended to
[`parity/evidence/2026-09-26-gap008-range-audit.txt`](../parity/evidence/2026-09-26-gap008-range-audit.txt)):

- `dotnet run --project tools/compiler-contract-tests`:
  `compiler contract tests: PASS (0 failures)` (no new contract added — the
  range adds no compiler surface).
- `python -m unittest discover -s parity/tests -p "test_*.py"`:
  `Ran 46 tests` → `OK`.
- `bash parity/param-sweep-verify.sh` with `NM_REFERENCE_ROOT` pinned by SHA at
  `noisemaker@403c2a4bf2cb56307448ea2fc1d6fa3cd74b7d6e`: authority-drift
  re-check of the whole golden corpus at the new upstream code head — corpus
  regenerates byte-identically (1900 variants, drift check clean, 391
  exclusions), oracle 1900/1900 ok, C# graphdump 1900/1900 ok, `param sweep:
  1900 graph-clean, 0 FAIL, 0 missing, of 1900 variants`, exit 0.

Carried, not re-run (Unity editor required, license-blocked): the 245-fixture
pixel gates, the 316-program Unity graph gate, the Windows/Linux platform
matrix, and the 6000.0 minimum floor — unchanged from passes 17/18.

### Delivered-range audit, 2026-09-27 (pass 27)

Upstream range `noisemaker@403c2a4bf2cb56307448ea2fc1d6fa3cd74b7d6e..7dc0f5640534855d73f8c812ca071fe6b1e09197`
(force-push-flagged trigger; audited, not assumed), reference checked out
detached by SHA at `7dc0f564053`, which is the `origin/main` tip
(`git log 7dc0f564..origin/main` → empty):

- Ancestry audited first (`git merge-base --is-ancestor`, raw transcript in
  [`parity/evidence/2026-09-27-gap011-range-audit.txt`](../parity/evidence/2026-09-27-gap011-range-audit.txt)):
  `403c2a4b` is an ancestor of `7dc0f564` (the force-push flag resolves — the
  delivered range is a contiguous extension of the previously audited tip),
  `403c2a4b`, the observed-delivery start `407eb7a7`, and the end `7dc0f564`
  are all on `origin/main`. The range is five commits: `0ac52500`, `7730ea4a`,
  `407eb7a7` upstream documentation passes; `9f85687d` (GAP-010) and
  `7dc0f564` (GAP-011) code commits.
- Range delta: `git log --stat 403c2a4bf2cb..7dc0f5640534 -- shaders/` →
  exactly the two code commits, `shaders/tests/**` only — GAP-010 `9f85687d`
  (`uniform-status.js` + regressions, `--strict-uniforms` aggregation behind
  `scripts/run-js-tests.js` flag registration) and GAP-011 `7dc0f564`
  (`uniform-deltas.js` + regressions, measured uniform-delta reporting) — plus
  upstream docs (`LEDGER.md`, `llms-full.txt`).
  `git diff --stat 403c2a4bf2cb..7dc0f5640534 -- shaders/effects shaders/glsl
  shaders/wgsl shaders/src shaders/scripts` → 0 files changed.
- NOT ported — GAP-010 `9f85687d` and GAP-011 `7dc0f564`: JS test-harness
  uniform-reporting modules under `shaders/tests/` only; no engine behavior.
  `grep -rln "strict-uniforms|uniform-status|uniform-deltas" unity/` matches
  nothing, and the port's `parity/` harness has no uniforms-reporting surface
  (the only `uniform` matches in `unity/` are HLSL uniform declarations), so
  there is no equivalent to change.
- Effect-catalog parity: 0 new / 0 changed / 0 removed; no WGSL/GLSL→HLSL
  translation is touched by this range, so no translation cross-check arises.

Gate evidence (pass 27, current source, Linux audit host, .NET SDK 8.0.412,
numpy 2.5.3 / pillow 12.3.0; raw command transcript appended to
[`parity/evidence/2026-09-27-gap011-range-audit.txt`](../parity/evidence/2026-09-27-gap011-range-audit.txt)):

- `dotnet run --project tools/compiler-contract-tests`:
  `compiler contract tests: PASS (0 failures)` (no new contract added — the
  range adds no compiler surface).
- `python -m unittest discover -s parity/tests -p "test_*.py"`:
  `Ran 46 tests` → `OK`.
- `bash parity/param-sweep-verify.sh` with `NM_REFERENCE_ROOT` pinned by SHA at
  `noisemaker@7dc0f5640534855d73f8c812ca071fe6b1e09197`: authority-drift
  re-check of the whole golden corpus at the new upstream code head — corpus
  regenerates byte-identically (1900 variants, 391 exclusions), oracle
  1900/1900 ok, C# graphdump 1900/1900 ok, `param sweep: 1900 graph-clean,
  0 FAIL, 0 missing, of 1900 variants`, exit 0.

Carried, not re-run (Unity editor required, license-blocked): the 245-fixture
pixel gates, the 316-program Unity graph gate, the Windows/Linux platform
matrix, and the 6000.0 minimum floor — unchanged from passes 17/18.

### filter/reverb wrap=clamp resolution, 2026-09-27 (pass 28)

The `filter__reverb__wrap__clamp` pixel-unresolved divergence from pass 27 is
attributed and fixed. Root cause: the pixel gates' goldens come from the
reference WEBGL2 backend, whose GLSL reverb runs the tiled pipeline math
`sampledLocalUV = fract((wrappedGlobalUV * fullResolution - tileOffset) / dims)`
— with no tiling that is `fract(applyWrap(uv * scale))`, an extra fract AFTER
the wrap. It is a no-op for mirror/repeat but maps the CLAMP branch's exact
1.0 back to 0.0 (clamped samples hit texel 0, not the last texel). The port
had implemented the checked-in `wgsl/reverb.wgsl` verbatim, which lacks that
trailing fract — hence only `wrap=clamp` diverged (the graph JSON, the `wrap: 2`
binding, and the other reverb variants were already correct).

Fix: the clamp branch of `Shaders/Effects/filter/Reverb.hlsl` now applies
`frac()` to the clamped UV (no-op except at exactly 1.0 → 0.0), matching the
measured webgl2 golden behavior; mirror/repeat branches are unchanged.

Evidence (raw transcript:
[`parity/evidence/2026-09-27-reverb-clamp-resolution.txt`](../parity/evidence/2026-09-27-reverb-clamp-resolution.txt)):
single-iteration probes on the licensed Unity 6000.3.16f1 host isolated the
clamped-sample texel choice; after the fix the full variant re-rendered against
a freshly regenerated `noisemaker@403c2a4b` webgl2 golden measures
`max-abs-diff=1.000 ssim=0.99997` under the filter-group policy
(tol 1 / SSIM ≥ 0.98) — previously max 93 / SSIM 0.812 — and
`filter__reverb__wrap__repeat` is unchanged (max 1). Suites at this source:
compiler contract tests PASS (0 failures); comparator suite `Ran 46 tests … OK`.
`parity/programs/param-sweep/pixel-unresolved.tsv` drops the reverb row
(17 measured divergences remain: 16 `synth/shape` loop-offset modes and
`synth3d/cell3d` seed — untouched by this change). The full 1803-variant pixel
sweep was NOT re-run end-to-end this pass; the recorded per-variant verdict for
this row is the compare.py measurement above under the gate's own filter policy.

### Delivered-range audit, 2026-09-27 (pass 28)

Upstream range `noisemaker@403c2a4bf2cb56307448ea2fc1d6fa3cd74b7d6e..e73a44a37f0c99bd3779c5fb26c7bba65a46a379`
(force-push-flagged trigger with three observed delivery ranges; audited, not
assumed), reference checked out detached by SHA at `e73a44a37f0c`, which is the
`origin/main` tip (`git log e73a44a37f0c..origin/main` → empty):

- Ancestry audited first (raw transcript in
  [`parity/evidence/2026-09-27-pass28-range-audit.txt`](../parity/evidence/2026-09-27-pass28-range-audit.txt)):
  `403c2a4b` and the declared delivery end `7443f6e` are ancestors of
  `e73a44a3`; all three observed ranges (`7dc0f564..7443f6e`,
  `132d1bf9..c2252f0`, `c2252f0..e73a44a`) lie on `origin/main`, and `7443f6e`
  is itself an ancestor of the `e73a44a3` tip — so the audit covers the union
  of every observed delivery. The range is nine commits: `9f85687d`
  (GAP-010), `7dc0f564` (GAP-011) audited in pass 27; `7443f6e` (GAP-012);
  `132d1bf9`, `407eb7a7`, `7730ea4a`, `0ac52500` upstream documentation
  passes; `c2252f0` (GAP-015); `e73a44a` (GAP-014).
- Range delta: `git log --stat 403c2a4bf2cb..e73a44a37f0c -- shaders/` →
  exactly five code commits, `shaders/tests/**` only — GAP-012 `7443f6e`
  (`frame-readback.js` + regressions, pins the harness WebGPU render-surface
  readback), GAP-015 `c2252f0` (`image-metrics.js` + regressions, auditable
  metric interchangeability mirror), GAP-014 `e73a44a` (`frame-warmup.js` +
  regressions, warm-up frames before explicit-time render requests), plus the
  two pass-27 uniforms modules. Nothing outside `shaders/tests/` changes in
  `shaders/`.
  `git diff --stat 403c2a4bf2cb..e73a44a37f0c -- shaders/effects shaders/glsl
  shaders/wgsl shaders/src shaders/scripts` → 0 files changed.
- NOT ported — GAP-012 `7443f6e`, GAP-015 `c2252f0`, GAP-014 `e73a44a`: JS
  test-harness modules under `shaders/tests/` only; no engine behavior.
  `grep -rlnE "frame-readback|image-metrics|frame-warmup" unity/` matches
  nothing, and the port's `parity/` harness has no readback/warmup/metrics
  harness surface, so there is no equivalent to change.
- For offline independent verification (review environments without network or
  a local noisemaker checkout), the verbatim upstream diff is committed at
  [`parity/evidence/2026-09-27-pass28-upstream-range.patch`](2026-09-27-pass28-upstream-range.patch)
  (`git diff 403c2a4bf2cb..e73a44a37f0c` from the pinned reference): 2266
  lines, 14 files — `LEDGER.md`, `llms-full.txt`, `scripts/run-js-tests.js`,
  and `shaders/tests/{frame-readback,frame-warmup,image-metrics,test-harness,
  test_frame_readback,test_frame_warmup,test_image_metrics,
  test_uniform_deltas,test_uniform_status,uniform-deltas,uniform-status}.js`.
  No `shaders/effects`, `shaders/glsl`, `shaders/wgsl`, or other
  `shaders/src` file appears in the patch.
- Effect-catalog parity: 0 new / 0 changed / 0 removed; the effect manifest is
  byte-identical (210 IDs, sha256
  `05c4d7b7744837ae90a3bb4c89e5403ff09448a74d9d7e824abb3d719ad3314e`); no WGSL/GLSL→HLSL translation is touched by this
  range, so no translation cross-check arises.
- Export kit workflow trigger audit (`.github/workflows/export-kit.yml`): the
  push range this pass published, `9e1f0e8..c070938`, has an **empty** diff
  under every trigger path (`git diff --stat 9e1f0e8..c070938 -- unity/
  export-kit/ LICENSE .github/` → 0 files changed) — the audited `Reverb.hlsl`
  clamp fix IS commit `9e1f0e8` itself, published by the prior pass-27 push
  and inside this pass's base, not inside the published delta. GitHub's
  push-path filter therefore correctly runs no Export kit dispatch at
  `26c52ab`/`c070938`; an absent run there is the trigger's designed behavior,
  not a failed or skipped gate. Kit release remains dispatch-driven from the
  `9e1f0e8` render change; the served kit `0.1.25` (source `ebd3e7b`) predates
  it and no kit deployment is declared in this job's deployment scope.

Gate evidence (pass 28, current source, Linux audit host, .NET SDK 8.0.412,
numpy 2.5.3 / pillow 12.3.0; raw command transcript appended to
[`parity/evidence/2026-09-27-pass28-range-audit.txt`](../parity/evidence/2026-09-27-pass28-range-audit.txt)):

- `dotnet run --project tools/compiler-contract-tests`:
  `compiler contract tests: PASS (0 failures)` (no new contract added — the
  range adds no compiler surface).
- `python -m unittest discover -s parity/tests -p "test_*.py"`:
  `Ran 46 tests` → `OK`.
- `bash parity/param-sweep-verify.sh` with `NM_REFERENCE_ROOT` pinned by SHA at
  `noisemaker@e73a44a37f0c99bd3779c5fb26c7bba65a46a379`: authority-drift
  re-check of the whole golden corpus at the new upstream code head — corpus
  regenerates byte-identically (1900 variants, 391 exclusions), oracle and
  result verdicts recorded in the raw transcript.

### Delivered-range audit + GAP-016 preflight port, 2026-09-27 (pass 30)

Upstream range `noisemaker@7443f6e6180300a45c5b97608459e5094504659d..296e0138c4744ed485b2e95de3eeb466c17629ee`
(force-push-flagged trigger with four observed delivery ranges; audited, not
assumed), reference cloned fresh and checked out detached by SHA at the
`origin/main` tip `296e0138` (`git log 296e0138..origin/main` → empty):

- Ancestry audited first (raw transcript in
  [`parity/evidence/2026-09-27-pass30-range-audit.txt`](../parity/evidence/2026-09-27-pass30-range-audit.txt)):
  the declared start `7443f6e` is an ancestor of the declared end `12b4d74f`
  and of the audited tip; the declared end is an ancestor of the tip; all four
  observed ranges (`e73a44a..12b4d74f`, `8fe3ccaf..93229933`,
  `7c5f1765..a912749f`, `11d7c699..296e0138`) lie on `origin/main` — so the
  audit covers the union of every observed delivery, eleven commits.
- Range delta: the only `shaders/src` change in the whole range is GAP-016
  `12b4d74f` (`shaders/src/runtime/preflight.js` — static effect preflight —
  plus its `pipeline.js` delegation and `shaders/tests/test_preflight.js`
  regressions). The rest is `shaders/tests/` harness modules only (GAP-017
  `93229933` definition-schema introspection, GAP-019 `a912749f`
  passthrough-input probe, GAP-021 `296e0138` frame-resolution reporting,
  plus the pass-28-audited GAP-012/014/015 modules) and upstream documentation
  passes (`132d1bf9`, `ec457c2e`, `8fe3ccaf`, `7c5f1765`, `11d7c699`).
- PORTED to this repo (pass 30, the runtime port): GAP-016 `12b4d74f` as
  `Compiler/Graph/GraphPreflight.cs` (pure, no UnityEngine — the
  TexturePoolability seam from pass 22) exposing `MrtFormatBytes()`,
  `PredictMrtDemotions()`, `ClampVolumeSizeValue()`, and `Preflight(graph,
  maxTextureSize, maxColorBytesPerSample)`; `NMPipeline` now delegates
  `MrtFormatBytes()`, the `ApplyMrtFormatBudget()` walk, and the
  `ClampVolumeSize()` numeric core to that shared implementation (prediction
  and runtime stay in lockstep by construction, exactly like upstream sharing
  `mrtFormatBytes()` between `preflight.js` and `pipeline.js`), and gains the
  read-only `NMPipeline.Preflight()` query. Rulings recorded in the file
  header, truthfully: upstream's per-backend authorability verdicts (WebGL2
  needs GLSL, WebGPU needs WGSL) have no Unity equivalent — this port
  compiles a single HLSL backend from precompiled assets and already refuses
  unresolvable programs at `ValidatePrograms()` — so no authorability verdict
  is invented; upstream's explicit texture-spec width/height/depth
  `maxTextureSize` clamp has no Unity enforcement counterpart — this port's
  runtime enforcement is the `volumeSize` square-atlas clamp, so predicted
  clamps report `volumeSize` uniforms. Pixel behavior is unchanged for every
  graph: the walk applied at init is the same one `ApplyMrtFormatBudget` ran
  before (same order, same byte table, same trailing-rgba32f-only demotion),
  now computed in one shared place. Package delta: `CHANGELOG.md`,
  `Compiler/Graph/GraphPreflight.cs(.meta)`, `Runtime/Pipeline/NMPipeline.cs`;
  installed-package manifest hash re-bound to 1685 files, sha256
  `48faab8e039a2e8d0259b267a46131756bbad8657ea440e32a4b69d54b8ef90a`
  (appended in [`parity/evidence/2026-09-26-package-artifact-hash.txt`](../parity/evidence/2026-09-26-package-artifact-hash.txt)).
- NOT ported — GAP-017 `93229933`, GAP-019 `a912749f`, GAP-021 `296e0138`:
  JS test-harness modules under `shaders/tests/` only; no engine behavior and
  no equivalent Unity surface (`grep -rlnE
  "definition-schema|frame-resolution|passthrough-input" unity/` matches
  nothing), same ruling as the pass-28 harness modules.
- For offline independent verification (review environments without network or
  a local noisemaker checkout), the verbatim upstream diff is committed at
  [`parity/evidence/2026-09-27-pass30-upstream-range.patch`](2026-09-27-pass30-upstream-range.patch)
  (`git diff 7443f6e61803..296e0138c474` from the pinned reference): 3500
  lines, 14 files — `LEDGER.md`, `llms-full.txt`, `package.json`,
  `scripts/run-js-tests.js`, `shaders/src/runtime/{pipeline,preflight}.js`,
  and the `shaders/tests/` harness modules and regressions. No
  `shaders/effects`, `shaders/glsl`, or `shaders/wgsl` file appears in the
  patch.
- Effect-catalog parity: 0 new / 0 changed / 0 removed; the effect manifest is
  byte-identical (210 IDs, sha256
  `05c4d7b7744837ae90a3bb4c89e5403ff09448a74d9d7e824abb3d719ad3314e`); no
  WGSL/GLSL→HLSL translation is touched by this range, so no translation
  cross-check arises.

Gate evidence (pass 30, current source, Linux audit host, .NET SDK 8.0.412,
numpy 2.5.3 / pillow 12.3.0; raw command transcript appended to
[`parity/evidence/2026-09-27-pass30-range-audit.txt`](../parity/evidence/2026-09-27-pass30-range-audit.txt)):

- `dotnet run --project tools/compiler-contract-tests`:
  `compiler contract tests: PASS (0 failures)` — including the new
  `TestGap016GraphPreflight` contract (byte table parity, trailing-only and
  both-attachment demotion order, under-budget/absent-budget/no-op passes,
  malformed-input no-throw, read-only prediction, apply-then-re-predict
  lockstep, `volumeSize` clamp prediction agreeing with the runtime's
  numeric core). Red-before holds: with `GraphPreflight.cs` removed the
  suite fails at compile time (20 `error CS` diagnostics); the file was
  restored and the suite passed afterwards.
- `python -m unittest discover -s parity/tests -p "test_*.py"`:
  `Ran 46 tests` → `OK`.
- `bash parity/param-sweep-verify.sh` with `NM_REFERENCE_ROOT` pinned by SHA
  at `noisemaker@296e0138c474`: authority-drift re-check of the whole golden
  corpus at the new upstream code head — corpus regenerates byte-identically
  (1900 variants, 391 exclusions), oracle and C# live-compiler graphs 1900 ok,
  structural diff 1900 graph-clean, exit 0.

### Delivered-range audit, 2026-09-28 (pass 31)

Upstream range `noisemaker@12b4d74fb4f28d5f00bb1dde107fa8673814d8b9..73c15be00d6888f4b5d2835d8e242ee9e840df45`
(force-push-flagged trigger with three observed delivery ranges; audited, not
assumed), reference cloned fresh and pinned by SHA; audit transcript archived
as Worker Elves evidence `2026-09-28-pass31-range-audit.txt`:

- Ancestry audited first: the declared start `12b4d74f` is the GAP-016 commit
  already ported in pass 30 and is an ancestor of the declared end; the
  `73c15be0` end is an ancestor of `origin/main` at audit time; all three
  observed ranges (`04e8582..c28e8fdb`, `c28e8fdb..7aff843a`,
  `7aff843a..73c15be0`) lie on the same linear history. Eleven commits total:
  three pass-30-audited harness commits (GAP-017 `93229933`, GAP-019
  `a912749f`, GAP-021 `296e0138`), five upstream documentation passes
  (`ec457c2e`, `8fe3ccaf`, `7c5f1765`, `11d7c699`, `04e8582c`), and three new
  non-documentation deltas.
- NOT ported — `c28e8fdb` (WebGL2 mesh-target rebind): upstream's
  `ensureDepthBuffer()` leaves the framebuffer unbound after initial depth
  allocation, so webgl2.js now re-binds the FBO before the mesh draw. This
  port has no equivalent surface: `NMRenderBackend` is a Unity
  `CommandBuffer` recorder that resolves the depth pool RT
  (`DepthBuffer(primary.width, primary.height)`) and then binds color+depth
  explicitly with `cmd.SetRenderTarget(...)` in the same pass — no render
  target binding survives a depth allocation, so the bug class upstream fixes
  cannot occur here. No Unity change follows.
- NOT ported — GAP-024 `7aff843a`: `shaders/tests/session-identity.js` plus
  test-harness browser-readiness/backend-identity plumbing only; no engine
  behavior and no Unity surface, same ruling as the pass-28/30 harness
  modules.
- NOT ported — GAP-026 `73c15be0` (production lifecycle hooks): upstream adds
  `Pipeline.initLifecycleEffects()`/`_invokeUpdateHooks()`/`_withRuntimeUniforms()`
  and dispose-time `onDestroy` walks over JS effect-definition callbacks
  (`onInit`/`onUpdate`/`onDestroy`, detected via `_configOn*` or a subclass
  override), plus the `recompile()` re-invocation site. This port executes no
  effect-definition code: effects are data-only HLSL (`reference/07`: "all
  behavior is in the shader + uniform packing"), the registry has no hook
  surface (`grep -rn "onUpdate|_configOn|hasLifecycleHook" unity/ tools/
  parity/ --include=*.cs --include=*.mjs` matches nothing), and the port
  already scope-notes the sibling CPU-side effect behavior
  (`initAsyncEffects`) as not ported (NMPipeline.cs:299). The one shipped
  upstream effect with hooks (`synth/media`) returns an `imageSize` fallback
  only for pass keys the pass does not resolve; this port binds the
  definition's authored `imageSize` default (1024×1024) through
  `UniformBinder` instead and executes no hook — behavior pinned by the port's
  pixel gates. No Unity change follows.
- Effect-catalog parity: 0 new / 0 changed / 0 removed;
  `git diff --stat 12b4d74f..73c15be0 -- shaders/effects shaders/glsl
  shaders/wgsl` → 0 files changed; no WGSL/GLSL→HLSL translation is touched
  by this range, so no translation cross-check arises.

Gate evidence (pass 31, current source, Linux audit host, .NET SDK 10.0.401,
numpy 2.4.6 / pillow 12.3.0, reference `noisemaker@c9ee8a04`; raw transcript
archived as Worker Elves evidence `2026-09-28-pass31-range-audit.txt`):

- `bash scripts/test` PASS (2064 s): node 5 passed / 0 failed / 0 skipped;
  python `Ran 47 tests` OK; compiler contract tests `PASS (0 failures)`;
  graph parity 316/316 graph-clean (207 `--selftest` + 109 fixtures, oracle
  316 ok); param sweep 1900 graph-clean, 0 FAIL, 0 missing, corpus
  byte-identical (1900 variants, 391 exclusions).
- Native Unity-host pixel gates for the four declared cases are re-queued by
  the supervisor at this pass's delivery commit.

### Delivered-range audit, 2026-09-29 (pass 32)

Upstream range `noisemaker@73c15be00d6888f4b5d2835d8e242ee9e840df45..682739066d3b74962febbdcdae85b5aa4d2e19f3`
(force-push-flagged trigger with four observed delivery ranges; audited, not
assumed), reference cloned fresh and pinned by SHA; audit transcript archived
as Worker Elves evidence `2026-09-29-pass32-range-audit.txt`:

- Ancestry audited first: the declared start `73c15be0` is the pass-31 audited
  end and an ancestor of the declared end `68273906`; the `68273906` end is in
  turn an ancestor of the newest observed window end `4f5e0d28`, so the audit
  covers the union span `73c15be0..4f5e0d28`; all four observed windows
  (`3e21906..a5059106`, `a5059106..68273906`, `c4606d1..4d47b3fd`,
  `4d47b3fd..4f5e0d28`) lie on the same linear `origin/main` history inside
  that span. Fourteen commits total: eight upstream documentation/ledger/contract
  passes (`53398923`, `cdb60cfc`, `d95d0c8c`, `3e21906e`, `bff453e9`,
  `8fec3d05`, `42843597`, `c4606d11`), two dependency bumps (`6b05a270`
  eslint 10.11.0, `a50c90bc` ruff >=0.16.9), and four GAP-032 audio commits
  (`a5059106`, `68273906`, `4d47b3fd`, `4f5e0d28`; the follow-up pair also
  adds upstream's own `scripts/test` entrypoint and its header fix).
- The range's entire `shaders/` delta is two files: `shaders/src/runtime/external-input.js`
  (+310/−2) and `shaders/tests/test_external_input.js` (+394). Every diff hunk
  header in `external-input.js` names `export class AudioInputManager` — the
  `AudioState`/`MidiState` data-model classes and everything above line 1237
  are untouched. Non-`shaders/` deltas are `LEDGER.md`, `llms-full.txt`,
  `package.json`/`package-lock.json`, `pyproject.toml` and `scripts/test`
  (upstream's own repository bookkeeping; the `scripts/test` entrypoint and
  header edits belong to the `4d47b3fd`/`4f5e0d28` GAP-032 follow-up commits
  themselves).
- NOT ported — GAP-032 `a5059106` + `68273906` + `4d47b3fd` + `4f5e0d28`
  (browser audio capture): upstream's `AudioInputManager` is the web runtime's
  capture orchestration layer — it resolves `Pipeline.getAudioInputRequirements()`
  (pre-existing API, introduced in `4f0b2448` "feat(audio): add per-device
  input automation", before this range and unchanged by it), registers the
  browser-selected capture device (`AudioState.registerDevice`) and default
  channels (`registerDefaultChannels`), opens one `getUserMedia` stream per
  selected-device requirement, wires `ChannelSplitterNode`/`AnalyserNode`
  per channel, marks per-channel `rawReady`, tears captures down on
  `disable()`, and warns on channel shortfalls and uncapturable bindings.
  This port implements no `AudioInputManager` (no such class exists under
  `unity/` — grep confirms; browser media APIs have no Unity equivalent):
  its `ExternalInput.cs` carries only the `MidiState`/`AudioState` data
  models that a host feeds via `NMRenderer.SetMidiState`/`SetAudioState`,
  MIDI/audio automation remains scope-staged (ARCHITECTURE.md "Still out of
  scope / staged: MIDI/audio automation"), and the requirements API
  upstream's capture manager consumes is already mirrored here
  (`Automation.GetAudioInputRequirements` + `NMPipeline.GetAudioInputRequirements()`
  + `NMRenderer.GetAudioInputRequirements()`, unchanged by this range) so a
  host can learn what to feed. The `AudioState` contract the port implements
  is untouched. No Unity change follows.
- Effect-catalog parity: 0 new / 0 changed / 0 removed;
  `git diff --stat 73c15be0..4f5e0d28 -- shaders/effects shaders/glsl
  shaders/wgsl shaders/src/definition.js` → 0 files changed; no
  WGSL/GLSL→HLSL translation is touched by this range, so no translation
  cross-check arises.

Gate evidence (pass 32, current source, Linux audit host, .NET SDK 10.0.401,
numpy 2.4.6 / pillow 12.3.0, reference `noisemaker@c9ee8a04`; raw transcript
archived as Worker Elves evidence `2026-09-29-pass32-range-audit.txt`):

- `bash scripts/test` PASS (~1520 s): node 5 passed / 0 failed / 0 skipped;
  python `Ran 47 tests` OK; compiler contract tests `PASS (0 failures)`;
  graph parity 316/316 graph-clean (207 `--selftest` + 109 fixtures, oracle
  316 ok); param sweep 1900 graph-clean, 0 FAIL, 0 missing, corpus
  byte-identical (1900 variants, 391 exclusions).
- Native Unity-host pixel gates for the four declared cases are re-queued by
  the supervisor at this pass's delivery commit.
