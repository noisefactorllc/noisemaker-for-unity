// GraphPreflight.cs — static effect preflight, ported from noisemaker@12b4d74f
// (GAP-016): upstream `preflightEffect(definition, capabilities, shaders)` in
// shaders/src/runtime/preflight.js statically reports, BEFORE any pipeline
// initialization or compilation, the device-limit format changes the runtime
// will perform.
//
// This port carries the two predictions that THIS runtime actually performs:
//
//  - MRT demotion: NMPipeline.ApplyMrtFormatBudget demotes trailing rgba32f
//    attachments to rgba16f until a pass's color attachments fit the per-sample
//    byte budget. GraphPreflight shares the byte table (MrtFormatBytes) and the
//    demotion walk (PredictMrtDemotions) with the pipeline — prediction and
//    runtime stay in lockstep by construction, exactly like upstream sharing
//    mrtFormatBytes() between preflight.js and pipeline.js.
//  - maxTextureSize clamp: upstream clamps explicit texture-spec
//    width/height/depth fields; THIS port's maxTextureSize enforcement is the
//    volumeSize uniform square-atlas clamp (NMPipeline.ClampVolumeSize), so the
//    predicted clamps here are volumeSize uniforms (Field = uniform name).
//    Upstream's explicit-dimension clamp has no Unity enforcement counterpart
//    and is deliberately not invented.
//
// Upstream's per-backend authorability verdicts (webgl2 needs GLSL source,
// webgpu needs WGSL) have no Unity equivalent: this port compiles a single
// HLSL backend from precompiled shader assets and already refuses init at
// NMPipeline.ValidatePrograms when a program cannot resolve. No authorability
// verdict is invented here.
//
// Pure: never mutates the graph, never throws on malformed input (null /
// missing specs are skipped the same way ApplyMrtFormatBudget skips them).
//
// Pure C#, no UnityEngine. Operates on the normalized graph model only.

using System.Collections.Generic;
using Noisemaker.Hlsl.Compiler.Graph;

namespace Noisemaker.Hlsl.Compiler
{
    /// <summary>Predicted MRT attachment demotion (upstream "formatChanges").</summary>
    public sealed class GraphPreflightFormatChange
    {
        public string Texture { get; set; }
        public string Pass { get; set; }
        public string From { get; set; }
        public string To { get; set; }
        public int Budget { get; set; }
        // Bytes/sample the pass still needed at this demotion (the runtime's
        // ApplyMrtFormatBudget warning reports the same running total).
        public int Total { get; set; }
    }

    /// <summary>Predicted volumeSize clamp (this port's maxTextureSize enforcement).</summary>
    public sealed class GraphPreflightClamp
    {
        public string Pass { get; set; }
        public string Field { get; set; }
        public double Requested { get; set; }
        public int Limit { get; set; }
    }

    /// <summary>Static preflight report (upstream's formatChanges + clamps; no
    /// per-backend authorability in this port — see the file header).</summary>
    public sealed class GraphPreflightReport
    {
        public List<GraphPreflightFormatChange> FormatChanges { get; } =
            new List<GraphPreflightFormatChange>();
        public List<GraphPreflightClamp> Clamps { get; } =
            new List<GraphPreflightClamp>();
    }

    public static class GraphPreflight
    {
        /// <summary>
        /// Byte cost per sample of a color attachment format, for the MRT
        /// attachment budget. Unlisted formats (including defaulted rgba16f
        /// surfaces) cost 8. Shared with NMPipeline.ApplyMrtFormatBudget.
        /// </summary>
        public static int MrtFormatBytes(string format)
        {
            if (format == "rgba32f" || format == "rgba32float") return 16;
            if (format == "rgba8" || format == "rgba8unorm") return 4;
            return 8;
        }

        /// <summary>
        /// VolumeSize square-atlas clamp core shared with
        /// NMPipeline.ClampVolumeSize (which adds the device warning). A value
        /// whose width*height atlas exceeds maxTextureSize is pulled down to
        /// the largest power-of-two edge that fits; maxTextureSize &lt;= 0
        /// (unknown / no limit) leaves the value untouched.
        /// </summary>
        public static double ClampVolumeSizeValue(int maxTextureSize, double value)
        {
            if (maxTextureSize <= 0 || value * value <= maxTextureSize)
                return value;

            int clamped = 16;
            while ((clamped * 2) * (clamped * 2) <= maxTextureSize &&
                clamped * 2 < value)
                clamped *= 2;
            return clamped;
        }

        /// <summary>
        /// Predict the applyMrtFormatBudget() demotions for this graph: per
        /// multi-attachment pass, trailing rgba32f attachments demoted to
        /// rgba16f until the pass fits budget. Appends to <paramref name="changes"/>;
        /// never mutates the graph.
        /// </summary>
        public static void PredictMrtDemotions(RenderGraph graph, int budget,
            List<GraphPreflightFormatChange> changes)
        {
            if (graph == null || budget <= 0 ||
                graph.Passes == null || graph.Textures == null)
                return;

            foreach (Pass pass in graph.Passes)
            {
                if (pass == null) continue;
                int count = pass.Outputs != null ? pass.Outputs.Count : 0;
                if (count <= 1) continue;

                var specs = new TextureSpec[count];
                var texIds = new string[count];
                int total = 0;
                for (int i = 0; i < count; i++)
                {
                    string texId = pass.Outputs.EntryAt(i).Value;
                    TextureSpec spec;
                    graph.Textures.TryGetValue(texId, out spec);
                    texIds[i] = texId;
                    specs[i] = spec;
                    total += MrtFormatBytes(spec != null ? spec.Format : null);
                }
                if (total <= budget) continue;

                for (int i = count - 1; i >= 0 && total > budget; i--)
                {
                    TextureSpec spec = specs[i];
                    if (spec == null ||
                        (spec.Format != "rgba32f" && spec.Format != "rgba32float"))
                        continue;
                    changes.Add(new GraphPreflightFormatChange
                    {
                        Texture = texIds[i],
                        Pass = pass.Id,
                        From = spec.Format,
                        To = "rgba16f",
                        Budget = budget,
                        Total = total
                    });
                    total -= 8;
                }
            }
        }

        /// <summary>
        /// Static preflight of a normalized graph against this port's device
        /// limits (the Unity equivalents of upstream's capability report — see
        /// the file header): predicted MRT demotions and predicted volumeSize
        /// clamps. Read-only; never mutates the graph.
        /// </summary>
        public static GraphPreflightReport Preflight(RenderGraph graph,
            int maxTextureSize, int maxColorBytesPerSample)
        {
            var report = new GraphPreflightReport();
            if (graph == null) return report;

            PredictMrtDemotions(graph, maxColorBytesPerSample, report.FormatChanges);

            if (graph.Passes != null)
            {
                foreach (Pass pass in graph.Passes)
                {
                    if (pass == null || pass.Uniforms == null) continue;
                    int count = pass.Uniforms.Count;
                    for (int i = 0; i < count; i++)
                    {
                        var kv = pass.Uniforms.EntryAt(i);
                        if (kv.Value == null ||
                            kv.Value.Kind != UniformValueKind.Number ||
                            !IsVolumeSizeUniform(kv.Key))
                            continue;
                        double requested = kv.Value.Number;
                        double clamped = ClampVolumeSizeValue(
                            maxTextureSize, requested);
                        if (clamped != requested)
                        {
                            report.Clamps.Add(new GraphPreflightClamp
                            {
                                Pass = pass.PassName ?? pass.Id,
                                Field = kv.Key,
                                Requested = requested,
                                Limit = maxTextureSize
                            });
                        }
                    }
                }
            }
            return report;
        }

        private static bool IsVolumeSizeUniform(string name)
        {
            return name == "volumeSize" ||
                name.StartsWith("volumeSize_chain_", System.StringComparison.Ordinal) ||
                name.StartsWith("volumeSize_node_", System.StringComparison.Ordinal);
        }
    }
}
