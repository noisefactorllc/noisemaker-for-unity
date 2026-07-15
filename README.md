# Noisemaker for Unity

A parallel port of the Noisemaker shader engine — a separate reference engine, not bundled
with this package — to **Unity / HLSL**.
It renders **live procedural textures from the Polymorphic DSL**, aiming to be
**pixel-identical** to the JS/WebGPU reference engine, and exposes effects both as a
standalone renderer and as **Shader Graph (material) nodes**.

> **🚧 WIP — very early development.** This project is in **very early development and
> is not recommended for general use** until we have fully tested it, addressed
> performance, and provided detailed integration guidance. Most deterministic effects
> (generators / filters) render correctly and the Tier-1 programs are pixel-identical,
> but parity work is ongoing — notably the chaotic iterative simulations
> (`navierStokes`, `reactionDiffusion`, feedback) and agent / particle systems, plus
> the live-display color pipeline. Treat all current output as provisional.

## Layout

```
noisemaker-unity/
├─ README.md                 ← you are here
├─ ARCHITECTURE.md           ← system design; how each reference subsystem maps to C#/HLSL
├─ PORTING-GUIDE.md          ← the GLSL/WGSL → HLSL rulebook (read before porting a shader)
├─ docs/GRAPH-JSON-SCHEMA.md ← the Render Graph JSON contract (exporter ↔ C# runtime)
├─ reference/                ← precise re-implementer specs of every reference subsystem (01–10)
├─ unity/com.noisemaker.hlsl/← the Unity package (UPM, drop-in)
│  ├─ Runtime/   ← RenderGraph executor (CommandBuffer Blit pipeline; pipeline-agnostic)
│  ├─ Compiler/  ← C# DSL frontend (lex→parse→validate→expand) + shared graph model
│  ├─ Shaders/   ← NMCore/NMFullscreen includes + per-effect HLSL ports + NMBlit
│  ├─ ShaderGraph/← per-effect Custom Function node wrappers
│  ├─ Effects/   ← effect definition JSON consumed by the runtime
│  └─ Editor/    ← parity runner + tooling
├─ tools/                    ← Node: export-graph (golden), convert-definitions (regenerate Effects/*.json)
└─ parity/                   ← golden-image harness + comparison + test programs
```

## The core idea: a shared Render Graph

The reference compiles DSL into a **Render Graph** (`passes / programs / textures /
renderSurface`). That is the seam. Noisemaker for Unity produces the same graph two ways:

- **Golden / offline** — `tools/export-graph.mjs` runs the *unchanged reference*
  `compileGraph` and serialises the graph to JSON (zero graph-construction parity risk).
  Producing your own `graph.json` this way (and regenerating effect JSON with
  `tools/convert-definitions.mjs`) requires a checkout of the separate Noisemaker reference
  engine — point `NM_REFERENCE_ROOT` at its root; it is **not** included in this package. To
  render immediately with no external dependency, import the bundled **Quick Start** sample
  (it ships a ready `graph.json`) — see *Quick start* below.
- **Live / in-Unity** — the C# `Compiler/` port compiles DSL at runtime. It is validated
  by diffing its graph JSON against the golden path: 148/148 programs byte-clean (the 12
  parity programs + the full `--selftest` corpus) via `tools/graphdump` — see
  `parity/README.md` § Graph parity.

Both feed the same `NMPipeline` executor + HLSL shaders, so visual parity depends only
on the shaders and the executor — see [ARCHITECTURE.md](ARCHITECTURE.md).

## Quick start (once opened in Unity)

> Requires **Linear color space** (*Player ▸ Color Space*) and, for player builds, the
> `Noisemaker/*` shaders added to *Graphics ▸ Always Included Shaders*. See the package
> README (`unity/com.noisemaker.hlsl/README.md`) for the full, authoritative integration
> and build guide — the defaults will not "just work" in a build.

1. Add the package: *Package Manager → Add package from disk →*
   `noisemaker-unity/unity/com.noisemaker.hlsl/package.json`.
2. **Fastest first render (no reference-engine or Node dependency):** in *Package Manager →
   Noisemaker for Unity → Samples* tab, **Import "Quick Start"**. Then, per the sample's README:
   set *Color Space = Linear*, create a *Quad* with an *Unlit/Texture* material, add the
   `NMQuickStartExample` component, and assign **Graph Json** = `NoiseGraph.json` and
   **Target** = the Quad's `Renderer`; press **Play**. This renders the bundled
   `noise → blur` graph.
3. **Your own content:** add an `NMRenderer` component and assign a source — a `GraphJson`
   TextAsset (recommended/verified; produce one with `tools/export-graph.mjs`, which needs the
   separate reference engine — see *The core idea* above) **or** a `Dsl` string plus the
   `EffectDefinitions` TextAssets (live compiler; early/unverified). Then call `Rebuild()`.
4. Read `NMRenderer.Output` (an `ARGBHalf` `RenderTexture`, valid after the first frame)
   into any material, or drop a Noisemaker **Custom Function node** into a Shader Graph.

## Status

**Compiles and renders in Unity 6** (verified on 6000.3.16f1). The C# engine compiles
clean and all 184 effect shaders compile (re-verified after the v1.0.98 sync —
`filter/parallax` plus the lighting/refract/cellRefract/simpleAberration/remap
updates — via a batchmode package import + render pass); driving `NMParityRunner`
in batchmode produced correct
output for `solid` (exact `#FF8000` fill), `noise` (multi-octave RGB simplex), and a
multi-pass `noise → blur` chain (correctly softened — exercises pooled intermediates +
filter input sampling + per-pass selection). Parity-critical shaders (PCG, noise, cell,
blend, blur) were additionally hardened by adversarial line-by-line review vs the WGSL.

**Pixel parity verified** via the `parity/` harness (JS/WebGL2 golden in headless Chromium
↔ Unity candidate ↔ `compare.py`). **18 of 20 parity programs are pixel-identical**
(within 1/255 = float→8-bit rounding, SSIM 1.00000): the eight Tier-1 programs (`solid`,
`noise`, `cell`, `gradient`, `shape`, `osc2d`, the multi-pass `blur`, the two-surface mixer
`blendMode`), the 3D/mixer additions `palette3d`, `mashup`, `renderCubemap3d`, and
`renderCubemapSurface`, and the v1.0.98-sync programs `lighting`/`lighting_hm`,
`parallax_hm`, `cellRefract_mirror`, `simpleAberration`, and `remap_zones`. The remaining
two (`parallax`, `refract_mirror`) match at SSIM 1.00000 with 3–4 isolated pixels each
(ray-march refinement / mirror-seam pixels; upstream's own GLSL↔WGSL delta on these
effects is 7–11 px) — within their per-effect tolerance.

The Y-flip reconciliation the design anticipated is now solved properly: Unity flips Y once
per `DrawProcedural` into a RenderTexture, so textures of odd-vs-even render depth ended up
oppositely oriented (only exposed when a mixer samples two such inputs — `blendMode`).
`NMVertFullscreen` counter-flips clip-space Y by `_ProjectionParams.x`, making every pass
store one consistent orientation regardless of depth. sRGB/linear and FMA are confirmed
correct by the SSIM-1.0 matches.

Bringing up Unity + the parity harness surfaced (and fixed) real bugs static review missed:
C# variable shadowing, a `PassType` namespace clash, an `NMBlit` include path + `src` input
name, batchmode `Shader.Find` resolution, multi-pass `Material.FindPass` selection, ShaderLab
reserved-word collisions in the (now-removed, MPB-driven) `Properties` blocks, the HLSL
reserved word `point` in `Cell.hlsl`, and `export-graph` starter-op + compile-time-`define`
promotion. See `parity/README.md` for the runbook.

**Effect coverage: 185 effect definitions** — every namespace complete:
`synth` 29 · `filter` 91 · `mixer` 15 · `classicNoisedeck` 20 · `points` 10 · `synth3d` 7 ·
`filter3d` 2 · `render` 11 (the `render` count includes the `loopBegin`/`loopEnd`/`meshLoader`
control passes). 184 ship a renderable shader; `synth/media` is a definition-only stub (no
shader — external image/video input is out of scope).

Each ported effect ships an `.hlsl` core, a `.shader`, and a runtime `Effects/*.json`;
single-pass effects also ship a Shader Graph Custom Function node. Every port is faithful to
the reference **WGSL**; PRNG-heavy, multi-pass, agent, and 3D ports were additionally
hardened by adversarial line-by-line review against the WGSL.

The runtime was hardened in stages to execute the harder patterns: **feedback/state**
(persistent surfaces, `repeat:` ping-pong, MRT), **agents** (`DrawProcedural(Points)`
scatter + additive deposit + `rgba32f` state), and **3D/mesh** (64×4096 volume atlas +
raymarch, OBJ loader + mesh-data textures, loop expansion). The C# DSL frontend handles
multi-statement programs, `read(oN)` / mid-chain `.write()`, `let` bindings, multi-input
(mixer) chains, `loopBegin`/`loopEnd`, and the 3D lane (`read3d`/`write3d`/`textures3d`,
graph-verified against the reference); `subchain` and `if`/`elif` remain staged.

`tools/convert-definitions.mjs` regenerates all effect-definition JSONs automatically; the
per-effect port path is documented in [PORTING-GUIDE.md](PORTING-GUIDE.md).

## Contributing

Issues and pull requests are welcome. Please review the [Code of Conduct](CODE_OF_CONDUCT.md) before opening changes.

## License

Noisemaker for Unity is released under the [MIT License](LICENSE). Use of the Noisemaker and Noise Factor names in derivative products is subject to the [Trademark Policy](TRADEMARK.md).

Copyright © 2026 Noise Factor LLC
