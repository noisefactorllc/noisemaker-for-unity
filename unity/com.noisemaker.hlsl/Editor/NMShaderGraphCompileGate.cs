// NMShaderGraphCompileGate.cs — compile-probe every ShaderGraph Custom Function wrapper.
//
// THE GAP: the 138 ShaderGraph/CustomFunctions/*.hlsl wrappers are consumed by a Shader
// Graph Custom Function node, whose generated fragment receives UnityTexture2D /
// UnitySamplerState (SRP Core structs) — NOT bare Texture2D / SamplerState. Wrappers were
// only ever compiled against the runtime .shader path, so SRP-Core-only defects (missing
// declarations, reserved-word locals, wrong argument counts, UnityTexture2D.GetDimensions
// — the SRP struct has no such method) never surfaced until a node actually included them.
//
// THE FIX: for each wrapper, generate a probe shader whose fragment calls the wrapper's
// NM_*_float entry with the exact Custom Function node calling convention:
//   - every UnityTexture2D param ← one shared UnityTexture2D built from a probe texture
//     via SRP Core's UnityBuildTexture2DStruct (the same struct SG hands the node),
//   - every UnitySamplerState param ← UnityBuildSamplerStateStruct(sampler),
//   - scalar params ← neutral float/int literals, every `out` value used (returned).
// The pass is force-compiled with ShaderUtil.CompilePass and any error message fails the
// gate. This is the Custom Function node compile context on the editor that runs it —
// run it in a project that has com.unity.render-pipelines.core (+ com.unity.shadergraph).
//
// Batchmode entry (used by the wrapper compile gate and by host probes):
//   Unity -batchmode -quit -projectPath <proj> \
//     -executeMethod Noisemaker.Hlsl.Editor.NMShaderGraphCompileGate.CompileAllFromCommandLine \
//     [-nmGateFilter <name-substring>] [-nmGateKeep]
// Exit code 0 when every wrapper pass compiles with zero error messages, 2 otherwise.
// Probe shaders are generated under Assets/NMSGateProbe and deleted again unless
// -nmGateKeep is passed.

#if UNITY_EDITOR
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using UnityEditor;
using UnityEngine;

namespace Noisemaker.Hlsl.Editor
{
    public static class NMShaderGraphCompileGate
    {
        public const string PackageRoot = "Packages/com.noisemaker.hlsl";
        public const string WrappersRel = "ShaderGraph/CustomFunctions";
        public const string ProbeDir = "Assets/NMSGateProbe";

        // ---- Batchmode / menu entry --------------------------------------------

        [MenuItem("Noisemaker/ShaderGraph/Compile All Custom Function Wrappers")]
        public static void CompileAllMenu()
        {
            int failed = CompileAll(null, keepGenerated: true);
            Debug.Log(failed == 0 ? "[NMSGate] PASS" : $"[NMSGate] FAIL ({failed} wrapper(s) with errors)");
        }

        public static void CompileAllFromCommandLine()
        {
            string filter = GetArg("-nmGateFilter");
            bool keep = GetArg("-nmGateKeep") != null;
            int failed = CompileAll(filter, keep);
            EditorApplication.Exit(failed == 0 ? 0 : 2);
        }

        // ---- Gate body ----------------------------------------------------------

        // Compiles every wrapper (or the -nmGateFilter subset). Returns the number of
        // wrappers that failed; 0 means the gate passed.
        public static int CompileAll(string nameFilter, bool keepGenerated)
        {
            string wrappersDir = Path.GetFullPath($"{PackageRoot}/{WrappersRel}");
            if (!Directory.Exists(wrappersDir))
            {
                Debug.LogError($"[NMSGate] FAIL: wrappers not found at {wrappersDir} " +
                               "(import the com.noisemaker.hlsl package first).");
                return 1;
            }

            var wrapperFiles = Directory.GetFiles(wrappersDir, "*.hlsl")
                .Select(Path.GetFileName)
                .Where(n => string.IsNullOrEmpty(nameFilter) || n.Contains(nameFilter))
                .OrderBy(n => n, StringComparer.Ordinal)
                .ToList();
            if (wrapperFiles.Count == 0)
            {
                Debug.LogError($"[NMSGate] FAIL: no wrapper matched filter '{nameFilter}'.");
                return 1;
            }

            Directory.CreateDirectory(ProbeDir);
            AssetDatabase.Refresh();

            int failures = 0;
            var failureLines = new List<string>();
            foreach (string name in wrapperFiles)
            {
                string assetPath = $"{ProbeDir}/{name}.shader";
                string code;
                try
                {
                    code = GenerateProbeShader(wrappersDir, name);
                }
                catch (Exception e)
                {
                    failures++;
                    failureLines.Add($"{name}: GENERATOR {e.Message}");
                    Debug.LogError($"[NMSGate] {name}: generator failed: {e.Message}");
                    continue;
                }
                File.WriteAllText(assetPath, code, new UTF8Encoding(false));
                AssetDatabase.ImportAsset(assetPath, ImportAssetOptions.ForceSynchronousImport);

                bool ok = false;
                string detail;
                try
                {
                    Shader shader = AssetDatabase.LoadAssetAtPath<Shader>(assetPath);
                    if (shader == null)
                    {
                        detail = "shader asset failed to import";
                    }
                    else
                    {
                        var material = new Material(shader);
                        ShaderUtil.CompilePass(material, 0, true);
                        ok = !ShaderUtil.ShaderHasError(shader);
                        detail = MessagesDetail(shader);
                        UnityEngine.Object.DestroyImmediate(material);
                    }
                }
                catch (Exception e)
                {
                    ok = false;
                    detail = e.Message;
                }

                if (ok)
                {
                    Debug.Log($"[NMSGate] OK {name}");
                }
                else
                {
                    failures++;
                    failureLines.Add($"{name}: {detail}");
                    Debug.LogError($"[NMSGate] FAIL {name}: {detail}");
                }
            }

            Debug.Log($"[NMSGate] NM-SG-GATE compiled={wrapperFiles.Count - failures}/{wrapperFiles.Count} failures={failures}");
            Debug.Log(failures == 0 ? "[NMSGate] RESULT PASS" : "[NMSGate] RESULT FAIL\n" + string.Join("\n", failureLines));

            if (!keepGenerated)
            {
                AssetDatabase.DeleteAsset(ProbeDir);
                AssetDatabase.Refresh();
            }
            return failures;
        }

        private static string MessagesDetail(Shader shader)
        {
            try
            {
                var messages = ShaderUtil.GetShaderMessages(shader);
                if (messages == null || messages.Length == 0)
                {
                    return ShaderUtil.ShaderHasError(shader) ? "shader has errors (no messages available)" : "";
                }
                var lines = messages
                    .Select(m => $"({m.line}) {m.message}");
                return string.Join("; ", lines.Distinct().Take(8));
            }
            catch (Exception e)
            {
                return "<messages unavailable: " + e.Message + ">";
            }
        }

        // ---- Probe shader generation --------------------------------------------

        private static readonly Regex EntryRegex =
            new Regex(@"void\s+(NM_\w+_float)\s*\(", RegexOptions.Compiled);

        // Emits one compile probe shader for <name>.hlsl and returns the shader text.
        public static string GenerateProbeShader(string wrappersDir, string name)
        {
            string source = File.ReadAllText(Path.Combine(wrappersDir, name));
            // Match on the comment-stripped source: a doc header may mention the
            // entry signature (Snow.hlsl does), which would otherwise parse the
            // comment's "(InputTex, SS, ...)" as the parameter list.
            string noComments = Regex.Replace(source, @"//[^\n]*", "");
            Match entry = EntryRegex.Match(noComments);
            if (!entry.Success)
                throw new InvalidOperationException("no NM_*_float entry found");
            string scanned = noComments;   // all indices below refer to this text

            int open = entry.Index + entry.Length - 1;   // position of '('
            int depth = 0, close = -1;
            for (int i = open; i < scanned.Length; i++)
            {
                if (scanned[i] == '(') depth++;
                else if (scanned[i] == ')') { depth--; if (depth == 0) { close = i; break; } }
            }
            if (close < 0)
                throw new InvalidOperationException("unbalanced entry signature");

            string raw = scanned.Substring(open + 1, close - open - 1);
            string cleaned = Regex.Replace(raw, @"/\*.*?\*/", "", RegexOptions.Singleline);

            var paramTexts = SplitTopLevel(cleaned);
            var args = new List<string>();
            var outArgs = new List<string>();
            foreach (string paramText in paramTexts)
            {
                string p = paramText.Trim();
                if (p.Length == 0) continue;
                Match m = Regex.Match(p, @"^(out\s+)?(\w+)\s+(\w+)$");
                if (!m.Success)
                    throw new InvalidOperationException($"unparsed parameter '{p}'");
                bool isOut = m.Groups[1].Success;
                string type = m.Groups[2].Value;
                string pname = m.Groups[3].Value;

                if (isOut)
                {
                    int idx = outArgs.Count;
                    args.Add("NMGateOut" + idx);
                    outArgs.Add(TypeDecl(type, "NMGateOut" + idx));
                }
                else
                {
                    args.Add(ValueFor(type, pname));
                }
            }
            if (outArgs.Count == 0)
                throw new InvalidOperationException("entry has no out parameter");

            var sb = new StringBuilder();
            string wrapperName = Path.GetFileNameWithoutExtension(name);
            sb.Append($@"// Generated by NMShaderGraphCompileGate — compile probe for ShaderGraph/CustomFunctions/{name}.
Shader ""Hidden/NMSGate/{wrapperName}""
{{
    Properties {{ _ProbeTex (""Probe"", 2D) = ""black"" {{}} }}
    SubShader
    {{
        Tags {{ ""RenderType"" = ""Opaque"" }}
        ZWrite Off ZTest Always Cull Off Blend Off
        Pass
        {{
            HLSLPROGRAM
            #pragma vertex NMGateVert
            #pragma fragment NMGateFrag
            #pragma target 4.5
            #pragma exclude_renderers gles

            // The Custom Function node compile context: SRP Core provides
            // UnityTexture2D / UnitySamplerState / the SAMPLE_TEXTURE2D* macros.
            #include ""Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl""
            #include ""Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl""

            TEXTURE2D(_ProbeTex);
            SAMPLER(sampler_ProbeTex);
            float4 _ProbeTex_TexelSize;
            float4 _ProbeTex_ST;

            #include ""{PackageRoot}/{WrappersRel}/{name}""

            struct NMGateAttrs {{ float4 positionOS : POSITION; float2 uv : TEXCOORD0; }};
            struct NMGateVaryings {{ float4 positionCS : SV_POSITION; float2 uv : TEXCOORD0; }};

            NMGateVaryings NMGateVert(NMGateAttrs v)
            {{
                NMGateVaryings o;
                o.positionCS = v.positionOS;
                o.uv = v.uv;
                return o;
            }}

            float4 NMGateFrag(NMGateVaryings i) : SV_Target
            {{
                UnityTexture2D NMGateTex = UnityBuildTexture2DStruct(_ProbeTex);
                UnitySamplerState NMGateSS = UnityBuildSamplerStateStruct(sampler_ProbeTex);
");
            foreach (string decl in outArgs) sb.AppendLine("                " + decl);
            sb.Append($"                {entry.Groups[1].Value}({string.Join(", ", args)});\n");
            sb.Append("                return NMGateOut0;\n");
            sb.Append(@"            }
            ENDHLSL
        }
    }
    Fallback Off
}
");
            return sb.ToString();
        }

        private static string TypeDecl(string type, string name)
        {
            switch (type)
            {
                case "float2": return $"float2 {name} = float2(0.5, 0.5);";
                case "float3": return $"float3 {name} = float3(0.5, 0.5, 0.5);";
                case "float4": return $"float4 {name} = float4(0.5, 0.5, 0.5, 0.5);";
                case "float":
                case "half": return $"float {name} = 0.5;";
                case "int":
                case "uint": return $"int {name} = 1;";
                default: throw new InvalidOperationException($"unhandled out type '{type}'");
            }
        }

        private static string ValueFor(string type, string pname)
        {
            switch (type)
            {
                case "UnityTexture2D": return "NMGateTex";
                case "UnitySamplerState": return "NMGateSS";
                case "float2": return "float2(0.5, 0.5)";
                case "float3": return "float3(0.5, 0.5, 0.5)";
                case "float4": return "float4(0.5, 0.5, 0.5, 0.5)";
                case "float":
                case "half": return "0.5";
                case "int":
                case "uint": return "1";
                case "bool": return "true";
                default: throw new InvalidOperationException($"unhandled param type '{type}' for '{pname}'");
            }
        }

        private static List<string> SplitTopLevel(string text)
        {
            var parts = new List<string>();
            int depth = 0;
            var cur = new StringBuilder();
            foreach (char c in text)
            {
                if (c == '(') depth++;
                if (c == ')') depth--;
                if (c == ',' && depth == 0) { parts.Add(cur.ToString()); cur.Clear(); }
                else cur.Append(c);
            }
            if (cur.Length > 0) parts.Add(cur.ToString());
            return parts;
        }

        private static string GetArg(string name)
        {
            string[] args = Environment.GetCommandLineArgs();
            for (int i = 0; i < args.Length - 1; i++)
                if (args[i] == name) return args[i + 1];
            return null;
        }
    }
}
#endif
