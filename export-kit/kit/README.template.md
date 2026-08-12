# {{NM_PROGRAM_NAME}}

Your program, exported from Noisedeck for **Unity**. It ships as a precompiled render graph plus the
Noisemaker UPM package that renders it, so Unity plays it into a `RenderTexture` you can put on a
material, a UI image, or anything else that samples a texture. It fetches nothing at runtime.

## Requirements

- **Unity 6** (the port is verified on `6000.3.16f1`; the package manifest allows 2021.3, but
  older editors are untested).
- **Linear color space — mandatory.** *Project Settings ▸ Player ▸ Color Space = Linear*. Every
  render target is `ARGBHalf`, non-sRGB. In a **Gamma** project (the Built-in and 2D template
  default) the colors come out silently wrong — washed-out and dark — with no error and no
  warning. This is the single most common way to get a bad result.
- **GPU: Shader Model 4.5+** (`#pragma target 4.5`). That rules out OpenGL ES 2 / 3.0, pre-DX11,
  and **WebGL**, and requires half/float render-target support.
- **Render pipeline:** verified on **Built-in**. The renderer submits a `CommandBuffer` and uses no
  SRP-specific hooks, so URP and HDRP are expected to work but are not yet verified. It renders to
  its own offscreen `RenderTexture`; presenting that full-screen is your job and differs per
  pipeline.
- **IL2CPP / AOT has not been validated.** Mono builds are the tested path.

## Install the package

Unzip this export somewhere outside your Unity project, then pick a route — the package lives in a
subfolder, not at a repo root:

- **From disk** (what this export is set up for): *Window ▸ Package Manager ▸ + ▸ Add package from
  disk…* → `engine/com.noisemaker.hlsl/package.json` in this folder. Unity references the package
  where it sits and does not copy it, so leave the unzipped folder where it is.
- **Embedded, if you would rather the package travelled with the project:** move
  `engine/com.noisemaker.hlsl/` into your project's **`Packages/`** folder (a sibling of `Assets/`,
  not inside it). Unity picks up embedded packages with no Package Manager step.
- **From git:** *Add package from git URL…* →
  `https://github.com/noisefactorllc/noisemaker-for-unity.git?path=unity/com.noisemaker.hlsl`

> **Never put `engine/` or `shaders/` inside `Assets/`.**
>
> `engine/` carries three assembly definitions and a `.meta` sidecar with a fixed GUID for every
> file. Copied into `Assets/` alongside a Package Manager install, Unity sees two assemblies named
> `Noisemaker.Hlsl.Runtime` and two of every GUID, and the project stops compiling.
>
> `shaders/` holds the per-effect shader sources for the effects your program uses — the `.shader`
> files plus the `.hlsl` they include — only as many as your program needs, not the package's full
> corpus. Each is byte-identical to the package's own copy, and each `.shader` declares the same name
> string the package's copy declares (`Shader "Noisemaker/synth/noise"`, and so on for every effect
> you exported). Unity keys its shader table on that string, so importing these alongside the package
> gives each a duplicate: Unity warns, and `Shader.Find("Noisemaker/…")` — which is how the runtime
> resolves every effect — starts returning whichever copy won. Read them where they sit; they are
> reference material, not project content.
>
> `Assets/` is for your content. The package belongs in `Packages/` or outside the project entirely,
> and the shader mirror stays in the unzipped export.

## Run it

1. Set the color space to Linear (see above). Do this first.
2. Install the package by one of the routes above.
3. **Copy only these files** into your project's `Assets/` (anywhere under it, a subfolder is
   fine): `graph.json`, `NMExportedGraph.cs`, and `program.dsl` if you want your source alongside.
   **Nothing else** — `engine/`, `shaders/`, `LICENSES/` and the kit metadata all stay in the
   unzipped export, for the reasons above. Unity imports `graph.json` as a `TextAsset` on its own.
4. Add `NMExportedGraph.cs` to any GameObject (*Add Component ▸ Noisedeck ▸ Exported Graph*). Unity
   adds the package's `NMRenderer` alongside it automatically.
5. Assign **Graph Json** → `graph.json`.
6. Press **Play**. With no **Target** assigned the component creates an unlit Quad in front of the
   main camera; assign a `Renderer` instead to draw onto geometry you already have.

`NMExportedGraph` is a small wrapper around the package's `NMRenderer`. To drive the renderer
yourself:

```csharp
using Noisemaker.Hlsl;

var r = gameObject.AddComponent<NMRenderer>();
r.GraphJson = graphJsonTextAsset;   // graph.json from this export
r.RenderWidth = 1024; r.RenderHeight = 1024;
r.Rebuild();                        // (re)build the pipeline after assigning a source

// Output is produced once per LateUpdate. It is null until the first frame and is
// recreated on Resize/Rebuild — re-read it, never cache it across either.
someMaterial.mainTexture = r.Output;
```

One note if you add `NMExportedGraph` from a script rather than in the Editor: `AddComponent` runs
the required `NMRenderer`'s `OnEnable` before the wrapper's `Awake` can hand it a graph, so Unity
logs one `no graph source (assign GraphJson or Dsl)` error, and the wrapper's `Start` builds the
graph a moment later. The render is correct; the error is a false alarm from the ordering. Add the
component in the Editor, or drive `NMRenderer` directly as above, and it does not appear.

## What's inside

| Path | What it is |
| --- | --- |
| `graph.json` | Your program, precompiled to the normalized render graph the runtime loads. This is the verified input path. |
| `NMExportedGraph.cs` | The sample MonoBehaviour above. Plain C# in the default assembly — no asmdef needed. |
| `program.dsl` | Your program's source, exactly as Noisedeck had it. |
| `noisedeck-export.json` | What was exported, when, against which engine build. |
| `engine/com.noisemaker.hlsl/` | The Unity package (UPM). Install it from here or move it to `Packages/` — never into `Assets/`. Present if you kept **include engine code** checked. |
| `shaders/` | The translated per-effect HLSL under `Effects/<ns>/`, plus the shared `Include/` the effects include from — the package's own `Shaders/` geometry, mirrored, so the `#include` paths resolve. Present if you kept **include shader code** checked. The package reads its own copy; this tree is for reading and editing **in place**, never for importing into `Assets/`. |
| `LICENSES/` | Licenses for everything shipped here. |

## graph.json versus live DSL

`graph.json` is precompiled by Noisedeck with the same engine the app renders with, so it needs no
effect registry and carries no compiler-parity risk. It is what this export is built around.

The package can also compile `program.dsl` at runtime, but that path is early, is not yet validated
against the precompiled one, and needs the package's `Effects/**/*.json` assigned as
`EffectDefinitions` TextAssets. `NMExportedGraph.cs` carries the wiring for it, commented out.
`GraphJson` wins whenever both are set.

## Builds

The runtime resolves each shader by name through `Shader.Find("Noisemaker/<ns>/<func>")`, and Unity
strips shaders nothing in a scene references. The package handles that: an Editor build step adds
every `Noisemaker/*` shader to *Always Included Shaders* for the duration of a player build and
restores your list afterward, so builds work with no setup — unless you strip the Editor assembly,
in which case run *Noisemaker ▸ Builds ▸ Add shaders to Always Included* once yourself.

Also worth knowing before you ship a build:

- Build-safe sources are `GraphJson` and `EffectDefinitions`. `EffectsDirectory` and
  `LoadMeshFromFile` use `System.IO` and are Editor-only.
- Mesh effects need OBJ data supplied as `TextAsset`s via `LoadMesh(...)`. No meshes are bundled,
  so mesh and 3D-geometry effects render nothing until you provide them.
- The renderer is output-only: no texture, camera, or video input.

## Cost

Nothing here is optimized yet, and some effects are expensive. The knobs, in order of effect:
render width and height (dominant for raymarch, fluid, and feedback effects — start at 256² and
work up); `stateSize` on particle and agent effects, which scales quadratically; and `Animate`,
which re-renders the whole graph every `LateUpdate`. For static output set `Animate = false` and
call `RenderFrame(t)` when you need a frame.

## Effects used by this program

{{NM_EFFECT_LIST}}

## The engine

Left **include engine code** checked? The package is here, at `engine/com.noisemaker.hlsl/`.
Install it by one of the routes above.

Already have the package installed? Then you only need `graph.json` and `NMExportedGraph.cs`, plus
`program.dsl` if you want your source alongside and `shaders/` if you kept **include shader code**
checked.

Do not have it at all? Install from git: *Package Manager ▸ + ▸ Add package from git URL…* →
`https://github.com/noisefactorllc/noisemaker-for-unity.git?path=unity/com.noisemaker.hlsl`

This export targets Noisemaker `{{NM_ENGINE_VERSION}}`. Pinning is deliberate: the graph keeps
rendering the same way after the engine moves on.

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| Washed-out, dark, or wrong colors | Project is in Gamma color space | Switch to Linear. |
| Nothing renders, no error | No source assigned, or `Output` read before the first frame | Assign **Graph Json**, then read `Output` after `LateUpdate`. |
| Black output, "Shader not found" in the log | Package shaders stripped from a build | Add `Noisemaker/*` to Always Included Shaders (see Builds). |
| A 3D or mesh effect renders nothing | No OBJ supplied | `LoadMesh(name, objTextAsset)`. |

## License

The Noisemaker engine and its Unity port are MIT licensed; see `LICENSES/`. Your program and the
imagery it renders are yours.
