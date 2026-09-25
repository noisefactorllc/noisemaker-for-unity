// TextureSpec.cs — a pooled / declared / global-override texture spec.
//
// Schema (GRAPH-JSON-SCHEMA.md "TextureSpec & dimensions", reference/03 §2.4):
//   { "width": <Dim>, "height": <Dim>, "depth"?: <Dim>, "is3D"?: bool,
//     "format"?: "rgba16f", "filter"?: "nearest"|"linear",
//     "mipmaps"?: bool, "persistent"?: bool }
//
// Width/Height are always present in emitted graphs. Depth is present only for 3D
// volumes. Is3D is true for 3D textures. Format defaults to "rgba16f" when absent
// (the DEFAULT is applied by the pipeline, NOT here — Format stays null if the
// JSON omits it, so the runtime can apply its own default and round-trip exactly).
//
// GAP-004 texture policies (noisemaker@2f47612c2904), carried as data only — the
// executor applies its previous defaults (engine-wide NEAREST point sampling,
// single mip level, no content preservation) when the fields are absent:
//   - Filter: 3D volumes only ("nearest" | "linear"). Null when absent.
//   - Mipmaps / Persistent: 2D specs only. Nullable booleans so "absent" is
//     distinguishable from "false" and round-trips exactly.

namespace Noisemaker.Hlsl.Compiler.Graph
{
    public sealed class TextureSpec
    {
        public Dim Width { get; set; }
        public Dim Height { get; set; }
        public Dim Depth { get; set; }      // null when 2D
        public bool Is3D { get; set; }       // false when absent
        public string Format { get; set; }   // null when absent; pipeline defaults to "rgba16f"
        public string Filter { get; set; }   // null when absent; 3D-only ("nearest"/"linear")
        public bool? Mipmaps { get; set; }   // null when absent; 2D-only mip-chain opt-in
        public bool? Persistent { get; set; } // null when absent; 2D-only recreate-preserving opt-in
    }
}
