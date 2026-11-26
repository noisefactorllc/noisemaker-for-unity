// Resources.cs — liveness analysis + linear-scan texture pooling, a 1:1 port of
// shaders/src/runtime/resources.js (reference/04 §1).
//
// Lives in the compiler (graph construction): allocateResources(passes) maps virtual
// pooled texIds to physical slots "phys_N". This is the producer of RenderGraph.Allocations.
//
// PARITY-CRITICAL (reference/04 §1.3, §14.4 / hazard 9):
//  - Allocation order within a pass follows Object.values(pass.outputs) INSERTION order;
//    release follows Object.values(pass.inputs) order. OrderedMap preserves this.
//  - Output allocation happens BEFORE input release in the same pass, so a tex read and
//    written at pass i cannot reuse its own slot (availableAfter=i is not < i).
//  - Free slot search picks the FIRST freeList entry with availableAfter < i.
//  - Only 'global_'-prefixed ids are excluded (infinite-lived).
//  - Fully deterministic, no float math.
//
// Pure C#, no UnityEngine. Operates on Graph.Pass (Inputs/Outputs OrderedMaps).

using System.Collections.Generic;
using Noisemaker.Hlsl.Compiler.Graph;

namespace Noisemaker.Hlsl.Compiler
{
    public static class Resources
    {
        private struct Lifetime { public int Start; public int End; }
        private struct FreeSlot { public string Id; public int AvailableAfter; }

        private static readonly System.Text.RegularExpressions.Regex NodeOutput =
            new System.Text.RegularExpressions.Regex(@"^node_[0-9]+_out$");

        private static Dictionary<string, string> ColorInputAliases(IReadOnlyList<Pass> passes)
        {
            var written = new HashSet<string>();
            foreach (Pass pass in passes)
                if (pass.Outputs != null) written.UnionWith(pass.Outputs.Values);

            var aliases = new Dictionary<string, string>();
            for (int i = 0; i < passes.Count; i++)
            {
                Pass pass = passes[i];
                if (pass.Inputs == null || string.IsNullOrEmpty(pass.NodeId)) continue;
                foreach (string input in pass.Inputs.Values)
                {
                    if (input != pass.NodeId + "_inputColor" && input != pass.NodeId + "_inputTex") continue;
                    if (written.Contains(input) || aliases.ContainsKey(input)) continue;
                    for (int j = i - 1; j >= 0 && !aliases.ContainsKey(input); j--)
                    {
                        if (passes[j].Outputs == null) continue;
                        foreach (string output in passes[j].Outputs.Values)
                        {
                            if (output == null || output == pass.NodeId + "_out" || !NodeOutput.IsMatch(output)) continue;
                            aliases.Add(input, output);
                            break;
                        }
                    }
                }
            }
            return aliases;
        }

        // reference/04 §1.1 analyzeLiveness.
        private static Dictionary<string, Lifetime> AnalyzeLiveness(IReadOnlyList<Pass> passes, Dictionary<string, string> aliases)
        {
            var lifetime = new Dictionary<string, Lifetime>();
            void Touch(string texId, int index)
            {
                if (string.IsNullOrEmpty(texId)) return;
                if (texId.StartsWith("global_")) return; // globals are infinite-lived
                Lifetime l;
                if (!lifetime.TryGetValue(texId, out l))
                    lifetime[texId] = new Lifetime { Start = index, End = index };
                else
                {
                    if (index < l.Start) l.Start = index;
                    if (index > l.End) l.End = index;
                    lifetime[texId] = l;
                }
            }

            for (int index = 0; index < passes.Count; index++)
            {
                Pass pass = passes[index];
                if (pass.Inputs != null)
                    foreach (string tex in pass.Inputs.Values)
                        Touch(tex != null && aliases.TryGetValue(tex, out string source) ? source : tex, index);
                if (pass.Outputs != null)
                    foreach (string tex in pass.Outputs.Values) Touch(tex, index);
            }
            return lifetime;
        }

        // reference/04 §1.2 allocateResources. Returns texId -> "phys_N".
        public static OrderedMap<string, string> AllocateResources(IReadOnlyList<Pass> passes)
        {
            var aliases = ColorInputAliases(passes);
            Dictionary<string, Lifetime> lifetime = AnalyzeLiveness(passes, aliases);
            var released = new HashSet<string>();
            var allocations = new OrderedMap<string, string>();
            var freeList = new List<FreeSlot>();
            int physicalCount = 0;

            for (int i = 0; i < passes.Count; i++)
            {
                Pass pass = passes[i];

                // 1. Allocate outputs (definitions).
                if (pass.Outputs != null)
                {
                    foreach (string texId in pass.Outputs.Values)
                    {
                        if (texId == null) continue;
                        if (texId.StartsWith("global_")) continue;
                        if (allocations.ContainsKey(texId)) continue;

                        int freeIdx = -1;
                        for (int k = 0; k < freeList.Count; k++)
                            if (freeList[k].AvailableAfter < i) { freeIdx = k; break; }

                        if (freeIdx != -1)
                        {
                            FreeSlot item = freeList[freeIdx];
                            freeList.RemoveAt(freeIdx);
                            allocations.Add(texId, item.Id);
                        }
                        else
                        {
                            string id = "phys_" + physicalCount++;
                            allocations.Add(texId, id);
                        }
                    }
                }

                // 2. Release inputs (last uses).
                if (pass.Inputs != null)
                {
                    released.Clear();
                    foreach (string input in pass.Inputs.Values)
                    {
                        if (input == null) continue;
                        string texId = aliases.TryGetValue(input, out string source) ? source : input;
                        if (!released.Add(texId)) continue;
                        if (texId.StartsWith("global_")) continue;
                        Lifetime l;
                        if (lifetime.TryGetValue(texId, out l) && l.End == i)
                        {
                            string physId;
                            if (allocations.TryGetValue(texId, out physId))
                                freeList.Add(new FreeSlot { Id = physId, AvailableAfter = i });
                        }
                    }
                }
            }
            return allocations;
        }
    }
}
