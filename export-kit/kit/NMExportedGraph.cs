// NMExportedGraph.cs — plays a Noisedeck export inside Unity.
//
// Modeled on the package's own Quick Start sample
// (com.noisemaker.hlsl/Samples~/QuickStart/NMQuickStartExample.cs): it drives an
// NMRenderer from a precompiled graph and puts the resulting RenderTexture on a
// material. The difference is the source — this one is wired for the files that
// came out of Noisedeck alongside it.
//
// Setup:
//   1. Project Settings ▸ Player ▸ Color Space = Linear. REQUIRED. In a Gamma
//      project every color is silently wrong (washed-out/dark) with no warning.
//   2. Install the package (Package Manager ▸ Add package from disk ▸ the
//      export's engine/com.noisemaker.hlsl/package.json), then copy ONLY
//      graph.json and this script into Assets/. Do NOT copy engine/ into
//      Assets/ — the package's assembly definitions and fixed .meta GUIDs would
//      be duplicated and the project would stop compiling. See the README.
//   3. Add this component to any GameObject and assign Graph Json = graph.json.
//      Unity adds the package's NMRenderer alongside it automatically.
//   4. Press Play. With no Target assigned it makes its own Quad; assign a
//      Renderer instead to draw onto geometry you already have.
//
// This script is plain C# in the default assembly. The package's runtime asmdef
// is auto-referenced, so `using Noisemaker.Hlsl;` resolves with no asmdef of
// your own and no changes to the package.

using UnityEngine;
using Noisemaker.Hlsl;

namespace Noisedeck.Export
{
    [AddComponentMenu("Noisedeck/Exported Graph")]
    [DisallowMultipleComponent]
    // NMRenderer builds its pipeline in its own OnEnable, so it has to already
    // exist and already be configured by then. RequireComponent puts it on the
    // GameObject at add-component time; Awake below fills it in.
    [RequireComponent(typeof(NMRenderer))]
    public sealed class NMExportedGraph : MonoBehaviour
    {
        [Header("Program")]
        [Tooltip("graph.json from this export, imported as a TextAsset. This is the " +
                 "precompiled path: no effect registry, and the parity-verified input.")]
        public TextAsset GraphJson;

        [Header("Display")]
        [Tooltip("Renderer that shows the output (e.g. a Quad's MeshRenderer). " +
                 "Leave empty to have this component create an unlit Quad in front of " +
                 "the main camera.")]
        public Renderer Target;

        [Header("Render target")]
        [Min(16)] public int Width = 1024;
        [Min(16)] public int Height = 1024;

        [Tooltip("Seconds per animation loop. Noisedeck plays a 15s loop; match it " +
                 "here to see the same motion you saw in the app.")]
        public float AnimationDuration = 15f;

        private NMRenderer _nm;
        private GameObject _ownedQuad;

        // Configuration happens in Awake, not OnEnable, and that ordering is the
        // whole point. Unity runs Awake on every component of a GameObject before
        // it runs OnEnable on any of them, so assigning GraphJson here means
        // NMRenderer.OnEnable — which calls Rebuild() unconditionally — finds its
        // source already set and builds the pipeline on the first frame.
        // Configuring in OnEnable instead is a coin flip on component order, and
        // loses it often enough that the normal path logs NMRenderer's red
        // "no graph source (assign GraphJson or Dsl)" before this script ever
        // gets to assign one.
        private void Awake()
        {
            _nm = GetComponent<NMRenderer>();  // guaranteed by RequireComponent

            if (GraphJson == null)
            {
                Debug.LogError("[Noisedeck] Assign Graph Json — the graph.json that shipped " +
                               "with this export, imported as a TextAsset.");
                return;
            }

            _nm.GraphJson = GraphJson;
            _nm.RenderWidth = Width;
            _nm.RenderHeight = Height;
            _nm.AnimationDuration = AnimationDuration;

            // ---- live-DSL fallback -----------------------------------------
            // program.dsl also shipped with this export, so the graph can be
            // compiled in-engine instead of loaded. That path is early and not
            // yet validated against the golden export, and it needs the package's
            // Effects/**/*.json assigned as TextAssets, so graph.json is the
            // default. To try it, drop GraphJson and uncomment:
            //
            //   _nm.GraphJson = null;                     // GraphJson wins when both are set
            //   _nm.Dsl = ProgramDsl.text;                // a TextAsset field for program.dsl
            //   _nm.EffectDefinitions = EffectJsonAssets;  // TextAsset[] of Effects/**/*.json
            //
            // Unity does not import a bare .dsl file, so rename it program.dsl.txt
            // first (or add a ScriptedImporter) to get a TextAsset out of it.
        }

        private void OnEnable()
        {
            if (Target == null) Target = CreateDisplayQuad();
        }

        // Start runs after every OnEnable, which makes it the right place for the
        // one ordering Awake cannot cover: a runtime AddComponent, where
        // RequireComponent adds NMRenderer and enables it before this component's
        // Awake has run. In the normal editor flow the graph is already built and
        // this does nothing.
        private void Start()
        {
            if (_nm == null || GraphJson == null) return;
            if (_nm.Graph == null) _nm.Rebuild();
        }

        private void OnDisable()
        {
            if (_ownedQuad != null)
            {
                Destroy(_ownedQuad);
                _ownedQuad = null;
                Target = null;  // ours to clear; a Target the user assigned stays put
            }
        }

        private void LateUpdate()
        {
            if (_nm == null || Target == null) return;

            // NMRenderer renders in its own LateUpdate, and Output is recreated on
            // resize and nulled on disable — re-fetch it each frame, never cache it.
            RenderTexture tex = _nm.Output;
            if (tex != null && Target.material != null)
                Target.material.mainTexture = tex;
        }

        // A Quad sized to fill the main camera's view, with an unlit material so
        // the export's own colors come through untouched by scene lighting.
        private Renderer CreateDisplayQuad()
        {
            _ownedQuad = GameObject.CreatePrimitive(PrimitiveType.Quad);
            _ownedQuad.name = "Noisedeck Export Quad";
            _ownedQuad.transform.SetParent(transform, false);

            Camera cam = Camera.main;
            if (cam != null)
            {
                float distance = 2f;
                _ownedQuad.transform.position = cam.transform.position + cam.transform.forward * distance;
                _ownedQuad.transform.rotation = cam.transform.rotation;
                float height = 2f * distance * Mathf.Tan(cam.fieldOfView * 0.5f * Mathf.Deg2Rad);
                _ownedQuad.transform.localScale = new Vector3(height * cam.aspect, height, 1f);
            }

            Renderer renderer = _ownedQuad.GetComponent<Renderer>();
            Shader unlit = Shader.Find("Unlit/Texture");
            if (unlit != null) renderer.material = new Material(unlit);
            return renderer;
        }
    }
}
