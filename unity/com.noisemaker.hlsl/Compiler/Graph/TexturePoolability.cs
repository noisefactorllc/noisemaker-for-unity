// TexturePoolability.cs — runtime texture-pooling safety analysis, ported from
// noisemaker@6113da00 (GAP-006) + 95743621 (viewport guard).
//
// Upstream's JS runtime historically allocated ONE backend texture per virtual
// texId and only recently gained opt-in consumption of the analyzer's physical
// allocation plan (`texturePooling: true` -> Pipeline.buildTexturePoolingPlan()).
// This Unity port has ALWAYS materialized graph.allocations (one phys_N RT per
// allocation group, TextureStore.AllocatePooled), so it consumes the plan by
// default. What this port was missing is upstream's POOLABILITY REFUSALS: a
// phys slot shared by virtuals with unsafe semantics must stay standalone.
// This class computes, purely from the graph, the set of virtual textures that
// may safely share their allocated phys slot, with the exact upstream refusal
// rules:
//
//   - global surfaces are double-buffered and never pooled (allocator already
//     excludes "global_" ids; restated here for the membership guard);
//   - a member whose FIRST touch in the pass list is an input read expects the
//     zero-initialized/previous-frame contents a standalone texture would hold;
//   - a member sampled by its own producing pass is refused;
//   - a member written by a partial/non-clearing pass is refused: any explicit
//     `drawMode` (points/billboards/triangles) scatters geometry without
//     covering the surface, `blend` makes the result depend on the
//     destination's previous contents, and a `viewport` pass WITHOUT a truthy
//     `clear` renders into a sub-region whose unwritten area exposes whatever
//     was there before (95743621). A full clear (`clear: true`, no viewport)
//     overwrites the whole texture and stays poolable;
//   - a group is pooled only when every member carries an identical plain 2D
//     spec: persistent textures keep cross-frame contents, mipmapped/3D specs
//     carry policy state a shared record must not absorb, and members with
//     mismatched (width, height, format) signatures fall back to standalone
//     textures;
//   - groups with fewer than two members are trivially standalone.
//
// Pixel behavior is unchanged for every graph where the previous C# pooling was
// already safe: the analysis only moves otherwise-aliased virtuals onto
// dedicated (texId-keyed) RenderTextures, matching the standalone semantics the
// reference runtime gives them.
//
// Pure C#, no UnityEngine. Operates on the normalized graph model only.

using System.Collections.Generic;
using Noisemaker.Hlsl.Compiler.Graph;

namespace Noisemaker.Hlsl.Compiler
{
    public static class TexturePoolability
    {
        // Returns the set of non-global virtual texIds that may share their
        // graph.allocations phys slot. Deterministic; no float math.
        public static HashSet<string> ComputePoolable(RenderGraph graph)
        {
            var poolable = new HashSet<string>();
            if (graph == null || graph.Allocations == null ||
                graph.Textures == null || graph.Passes == null)
                return poolable;
            if (graph.Allocations.Count == 0) return poolable;

            // First-touch classification from the pass list (upstream iterates the
            // pass list in order and, within one pass, outputs before inputs).
            var firstTouchIsWrite = new Dictionary<string, bool>();
            var selfSampled = new HashSet<string>();
            var partiallyWritten = new HashSet<string>();

            for (int i = 0; i < graph.Passes.Count; i++)
            {
                Pass pass = graph.Passes[i];
                if (pass == null) continue;

                // A pass that does not fully overwrite its target (scatter draw
                // modes, blending against the destination) leaves the texture's
                // previous contents observable, so pooled storage is unsafe.
                // A `viewport` pass that does not declare a truthy `clear`
                // renders into a sub-region whose unwritten area exposes whatever was there
                bool partial = !string.IsNullOrEmpty(pass.DrawMode) || pass.Blend;
                if (!partial && HasViewport(pass) && !GraphLoader.IsTruthy(pass.Clear))
                    partial = true;

                if (partial && pass.Outputs != null)
                    foreach (string texId in pass.Outputs.Values)
                        if (!string.IsNullOrEmpty(texId)) partiallyWritten.Add(texId);

                if (pass.Outputs != null)
                {
                    var inputSet = InputSet(pass);
                    foreach (string texId in pass.Outputs.Values)
                    {
                        if (string.IsNullOrEmpty(texId)) continue;
                        if (!firstTouchIsWrite.ContainsKey(texId))
                            firstTouchIsWrite[texId] = true;
                        if (inputSet.Contains(texId)) selfSampled.Add(texId);
                    }
                }
                if (pass.Inputs != null)
                {
                    foreach (string texId in pass.Inputs.Values)
                    {
                        if (string.IsNullOrEmpty(texId)) continue;
                        if (!firstTouchIsWrite.ContainsKey(texId))
                            firstTouchIsWrite[texId] = false;
                    }
                }
            }

            // Group members by physical slot (allocation order preserved).
            var groups = new Dictionary<string, List<string>>();
            foreach (var kv in graph.Allocations)
            {
                string texId = kv.Key;
                string physicalId = kv.Value;
                if (string.IsNullOrEmpty(physicalId) || !graph.Textures.ContainsKey(texId))
                    continue;
                if (texId.StartsWith("global_")) continue; // double-buffered, never pooled
                if (firstTouchIsWrite.TryGetValue(texId, out bool isWrite) && !isWrite)
                    continue; // first touch is a read
                if (selfSampled.Contains(texId)) continue;
                if (partiallyWritten.Contains(texId)) continue;
                if (!groups.TryGetValue(physicalId, out var members))
                {
                    members = new List<string>();
                    groups[physicalId] = members;
                }
                members.Add(texId);
            }

            foreach (var members in groups.Values)
            {
                if (members.Count < 2) continue;
                // Every member must carry an identical plain 2D spec: persistent
                // textures keep cross-frame contents; mipmapped/3D specs carry
                // policy state a shared record must not absorb.
                bool refused = false;
                for (int i = 0; i < members.Count; i++)
                {
                    graph.Textures.TryGetValue(members[i], out TextureSpec spec);
                    if (spec == null || spec.Persistent == true ||
                        spec.Mipmaps == true || spec.Is3D)
                    {
                        refused = true; break;
                    }
                }
                if (refused) continue;

                string signature = SpecSignature(graph.Textures, members[0]);
                for (int i = 1; i < members.Count; i++)
                {
                    if (SignatureOf(graph.Textures.TryGetValue(members[i], out TextureSpec s)
                            ? s : null) != signature)
                    {
                        refused = true; break;
                    }
                }
                if (refused) continue;

                foreach (string member in members) poolable.Add(member);
            }
            return poolable;
        }

        // `pass.viewport` truthiness: any authored viewport component (x/y/w/h,
        // GAP-005 grammar) makes the pass render into a sub-region. The loader
        // and the live Expander leave every field null when the viewport is
        // absent or JSON null.
        public static bool HasViewport(Pass pass)
        {
            return pass.ViewportX != null || pass.ViewportY != null ||
                pass.ViewportWidth != null || pass.ViewportHeight != null;
        }

        private static HashSet<string> InputSet(Pass pass)
        {
            var set = new HashSet<string>();
            foreach (string texId in pass.Inputs.Values)
                if (!string.IsNullOrEmpty(texId)) set.Add(texId);
            return set;
        }

        // Upstream signature: JSON.stringify([spec.width, spec.height, spec.format]).
        private static string SignatureOf(TextureSpec spec)
        {
            if (spec == null) return "null";
            return DimSignature(spec.Width) + "," + DimSignature(spec.Height) +
                "," + (spec.Format ?? "");
        }

        private static string SpecSignature(OrderedMap<string, TextureSpec> textures,
            string texId)
        {
            return SignatureOf(textures.TryGetValue(texId, out TextureSpec s) ? s : null);
        }

        private static string DimSignature(Dim d)
        {
            if (d == null) return "null";
            switch (d.Kind)
            {
                case DimKind.Number: return "n:" + d.Number.ToString("R");
                case DimKind.Screen: return "s:" + (d.ScreenLiteral ?? "");
                case DimKind.Percent: return "p:" + d.Percent.ToString("R");
                case DimKind.Param:
                    return "p:" + (d.Param ?? "") + ":" +
                        (d.ParamDefault.HasValue ? d.ParamDefault.Value.ToString("R") : "-") +
                        ":" + (d.Multiply.HasValue ? d.Multiply.Value.ToString("R") : "-") +
                        ":" + (d.Power.HasValue ? d.Power.Value.ToString("R") : "-") +
                        ":" + (d.DefaultValue.HasValue ? d.DefaultValue.Value.ToString("R") : "-");
                case DimKind.ScreenDivide:
                    return "d:" + (d.ScreenDivide ?? "") + ":" +
                        (d.DefaultValue.HasValue ? d.DefaultValue.Value.ToString("R") : "-");
                case DimKind.Scale:
                    return "c:" + d.Scale.ToString("R") + ":" +
                        (d.ClampMin.HasValue ? d.ClampMin.Value.ToString("R") : "-") +
                        ":" + (d.ClampMax.HasValue ? d.ClampMax.Value.ToString("R") : "-");
                default: return "?";
            }
        }
    }
}
