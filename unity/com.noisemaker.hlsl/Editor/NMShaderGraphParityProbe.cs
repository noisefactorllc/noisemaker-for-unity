using System;
using System.IO;
using System.Linq;
using System.Text;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace Noisemaker.Hlsl.Editor
{
    public static class NMShaderGraphParityProbe
    {
        private const int Size = 256;

        public static void Run()
        {
            string directory = Arg("-nmParityDir");
            string reportPath = Arg("-nmParityReport");
            string captures = Arg("-nmParityCaptures");
            if (string.IsNullOrEmpty(directory) || string.IsNullOrEmpty(reportPath) || string.IsNullOrEmpty(captures))
            {
                Debug.LogError("[NMSGParity] parity directory, report and captures are required");
                EditorApplication.Exit(2);
                return;
            }

            Directory.CreateDirectory(captures);
            var report = new StringBuilder();
            int failures = 0;
            foreach (string file in Directory.GetFiles(directory, "*.shadergraph").OrderBy(p => p))
            {
                string name = Path.GetFileNameWithoutExtension(file);
                try
                {
                    if (name != "Snow" && name != "Polar" && name != "Tunnel" &&
                        name != "Spiral" && name != "Refract" && name != "CellRefract" &&
                        name != "Kaleido" && name != "KaleidoShadow" &&
                        !name.StartsWith("Glitch") && !name.StartsWith("Effects"))
                        throw new InvalidOperationException("unknown parity case " + name);
                    Shader graphShader = AssetDatabase.LoadAssetAtPath<Shader>(file.Replace('\\', '/'));
                    string family = name == "Refract" || name == "CellRefract" || name.StartsWith("Kaleido") ||
                        name.StartsWith("Glitch") || name.StartsWith("Effects")
                        ? "classicNoisedeck" : "filter";
                    string shaderName = name == "KaleidoShadow" ? "Kaleido" :
                        name.StartsWith("Glitch") ? "Glitch" :
                        name.StartsWith("Effects") ? "Effects" : name;
                    Shader pipelineShader = AssetDatabase.LoadAssetAtPath<Shader>(
                        "Packages/com.noisemaker.hlsl/Shaders/Effects/" + family + "/" + shaderName + ".shader");
                    if (graphShader == null || pipelineShader == null)
                        throw new InvalidOperationException("shader asset missing");
                    var input = MakeInput();
                    var graph = new Material(graphShader);
                    var pipeline = new Material(pipelineShader);
                    try
                    {
                        graph.SetTexture("_BaseMap", input);
                        if (name == "EffectsSubpixel" || name == "EffectsTiled" ||
                            name == "EffectsSubpixelLowTiled" || name == "EffectsSubpixelLegacy" ||
                            name == "EffectsSubpixelScaled" || name == "EffectsSubpixelSaved")
                            graph.SetFloat("_NMParityEffectAmt", name == "EffectsSubpixelLowTiled" ? 2f : 5f);
                        if (name == "Spiral")
                            graph.SetFloat("_NMParityStrength", -100f);
                        if (name == "EffectsScaleMid")
                            graph.SetFloat("_NMParityScaleAmt", 212.5f);
                        pipeline.SetTexture("inputTex", input);
                        ShaderUtil.CompilePass(graph, 0, true);
                        ShaderUtil.CompilePass(pipeline, 0, true);
                        var compileErrors = ShaderUtil.GetShaderMessages(graphShader)
                            .Concat(ShaderUtil.GetShaderMessages(pipelineShader))
                            .Where(message => message.severity.ToString() == "Error").ToArray();
                        if (compileErrors.Length > 0)
                            throw new InvalidOperationException("shader compile error: " + compileErrors[0].message);
                        pipeline.SetVector("_NM_Resolution", new Vector4(Size, Size, 0, 0));
                        bool tiled = name.Contains("Tiled");
                        bool wide = name.EndsWith("TiledWide");
                        pipeline.SetVector("_NM_FullResolution", new Vector4(tiled ? Size * 2 : Size, tiled && !wide ? Size * 2 : Size, 0, 0));
                        pipeline.SetVector("_NM_TileOffset", tiled ? new Vector4(Size / 2, wide ? 0 : Size / 2, 0, 0) : Vector4.zero);
                        pipeline.SetFloat("_NM_RenderScale", name.EndsWith("Scaled") ? 2f : 1f);
                        pipeline.SetFloat("_NM_AspectRatio", 1f);
                        pipeline.SetFloat("_NM_Time", 0.25f);
                        if (name == "Snow")
                        {
                            pipeline.SetFloat("alpha", 0.5f);
                            pipeline.SetFloat("pause", 0f);
                            pipeline.SetFloat("density", 75f);
                        }
                        else if (name == "Polar")
                        {
                            pipeline.SetInt("polarMode", 0);
                            pipeline.SetFloat("scale", 0f);
                            pipeline.SetInt("rotation", 0);
                            pipeline.SetInt("speed", 0);
                            pipeline.SetInt("aspectLens", 1);
                            pipeline.SetInt("antialias", 1);
                        }
                        else if (name == "Tunnel")
                        {
                            pipeline.SetInt("shape", 0);
                            pipeline.SetFloat("scale", 0f);
                            pipeline.SetFloat("speed", 1f);
                            pipeline.SetFloat("rotation", 0f);
                            pipeline.SetFloat("center", 100f);
                            pipeline.SetInt("aspectLens", 1);
                            pipeline.SetInt("antialias", 1);
                        }
                        else if (name == "Spiral")
                        {
                            pipeline.SetFloat("strength", -100f);
                            pipeline.SetInt("speed", 0);
                            pipeline.SetFloat("rotation", 0f);
                            pipeline.SetInt("wrap", 0);
                            pipeline.SetInt("aspectLens", 1);
                            pipeline.SetInt("antialias", 1);
                        }
                        else if (name == "Refract")
                        {
                            pipeline.SetInt("mode", 0);
                            pipeline.SetFloat("amount", 50f);
                            pipeline.SetFloat("direction", 0f);
                            pipeline.SetInt("blendMode", 10);
                            pipeline.SetFloat("mixAmt", 50f);
                            pipeline.SetInt("wrap", 0);
                        }
                        else if (name == "CellRefract")
                        {
                            pipeline.SetFloat("refractAmt", 23f);
                            pipeline.SetFloat("direction", 0f);
                            pipeline.SetInt("wrap", 0);
                            pipeline.SetFloat("speed", 1f);
                            pipeline.SetInt("SHAPE", 1);
                            pipeline.SetFloat("scale", 50f);
                            pipeline.SetFloat("cellScale", 75f);
                            pipeline.SetFloat("cellSmooth", 0f);
                            pipeline.SetFloat("variation", 0f);
                            pipeline.SetInt("seed", 1);
                            pipeline.SetInt("KERNEL", 0);
                            pipeline.SetFloat("effectWidth", 0f);
                        }
                        else if (name == "Kaleido" || name == "KaleidoShadow")
                        {
                            pipeline.SetFloat("kaleido", 8f);
                            pipeline.SetInt("METRIC", 0);
                            pipeline.SetInt("LOOP_OFFSET", 10);
                            pipeline.SetFloat("loopScale", 1f);
                            pipeline.SetFloat("speed", 5f);
                            pipeline.SetInt("seed", 1);
                            pipeline.SetInt("wrap", 1);
                            pipeline.SetInt("DIRECTION", 2);
                            pipeline.SetInt("KERNEL", name == "KaleidoShadow" ? 6 : 0);
                            pipeline.SetFloat("effectWidth", 0f);
                        }
                        else if (name.StartsWith("Glitch"))
                        {
                            bool active = name != "Glitch";
                            pipeline.SetFloat("glitchiness", active ? 50f : 0f);
                            pipeline.SetFloat("aberration", active ? 25f : 0f);
                            pipeline.SetInt("xChonk", 1);
                            pipeline.SetInt("yChonk", 1);
                            pipeline.SetInt("seed", 1);
                            pipeline.SetInt("scanlinesAmt", active ? 20 : 0);
                            pipeline.SetFloat("snowAmt", active ? 20f : 0f);
                            pipeline.SetFloat("vignetteAmt", active ? -50f : 0f);
                            pipeline.SetFloat("distortion", active ? 30f : 0f);
                            pipeline.SetInt("aspectLens", 0);
                        }
                        else if (name.StartsWith("Effects"))
                        {
                            pipeline.SetInt("EFFECT", name.StartsWith("EffectsCga") ? 200 :
                                name.Contains("Subpixel") || name == "EffectsTiled" ? 210 :
                                name == "EffectsBlurTiled" ? 1 : 0);
                            pipeline.SetInt("FLIP", 0);
                            pipeline.SetFloat("effectAmt", name == "EffectsSubpixelLowTiled" ? 2f :
                                name == "Effects" || name == "EffectsScaleMid" || name == "EffectsBlurTiled" ? 1f : 5f);
                            pipeline.SetFloat("scaleAmt", name == "EffectsScaleMid" ? 212.5f : 100f);
                            pipeline.SetFloat("rotation", 0f);
                            pipeline.SetFloat("offsetX", 0f);
                            pipeline.SetFloat("offsetY", 0f);
                            pipeline.SetFloat("intensity", 0f);
                            pipeline.SetFloat("saturation", 0f);
                        }
                        Color32[] graphPixels = RenderGraph(graph, Path.Combine(captures, name + "-graph.png"));
                        Color32[] pipelinePixels = RenderPipeline(pipeline, Path.Combine(captures, name + "-pipeline.png"));
                        int maxDifference = 0;
                        int mismatched = 0;
                        for (int i = 0; i < graphPixels.Length; i++)
                        {
                            int difference = Math.Max(Math.Max(
                                Math.Abs(graphPixels[i].r - pipelinePixels[i].r),
                                Math.Abs(graphPixels[i].g - pipelinePixels[i].g)),
                                Math.Max(Math.Abs(graphPixels[i].b - pipelinePixels[i].b),
                                         Math.Abs(graphPixels[i].a - pipelinePixels[i].a)));
                            maxDifference = Math.Max(maxDifference, difference);
                            if (difference > 1) mismatched++;
                        }
                        bool pass = mismatched == 0;
                        report.AppendLine(name + "\t" + (pass ? "PASS" : "FAIL") +
                            "\tmax=" + maxDifference + "\tpixels=" + mismatched + "/" + graphPixels.Length);
                        if (!pass) failures++;
                    }
                    finally
                    {
                        UnityEngine.Object.DestroyImmediate(pipeline);
                        UnityEngine.Object.DestroyImmediate(graph);
                        UnityEngine.Object.DestroyImmediate(input);
                    }
                }
                catch (Exception error)
                {
                    report.AppendLine(name + "\tFAIL\t" + error.Message.Replace('\n', ' '));
                    failures++;
                }
            }
            File.WriteAllText(reportPath, report.ToString());
            Debug.Log("[NMSGParity] " + report);
            EditorApplication.Exit(failures == 0 ? 0 : 1);
        }

        private static Texture2D MakeInput()
        {
            var input = new Texture2D(Size, Size, TextureFormat.RGBA32, false, true)
            {
                filterMode = FilterMode.Point,
                wrapMode = TextureWrapMode.Clamp
            };
            var colors = new Color32[Size * Size];
            for (int y = 0; y < Size; y++)
            for (int x = 0; x < Size; x++)
                colors[y * Size + x] = new Color32(
                    (byte)((x * 17 + y * 31) & 255),
                    (byte)((x * 53 + y * 7) & 255),
                    (byte)((x * 11 + y * 47) & 255), 255);
            input.SetPixels32(colors);
            input.Apply();
            return input;
        }

        private static Color32[] RenderGraph(Material material, string path)
        {
            var mesh = new Mesh
            {
                vertices = new[] { new Vector3(-1, -1, 0), new Vector3(-1, 3, 0), new Vector3(3, -1, 0) },
                uv = new[] { new Vector2(0, 0), new Vector2(0, 2), new Vector2(2, 0) },
                triangles = new[] { 0, 1, 2, 0, 2, 1 }
            };
            var target = new RenderTexture(Size, Size, 24, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
            var commands = new CommandBuffer();
            try
            {
                target.Create();
                commands.SetRenderTarget(target);
                commands.ClearRenderTarget(true, true, Color.clear);
                commands.SetViewProjectionMatrices(Matrix4x4.identity, Matrix4x4.identity);
                commands.DrawMesh(mesh, Matrix4x4.identity, material, 0, 0);
                Graphics.ExecuteCommandBuffer(commands);
                return Read(target, path);
            }
            finally
            {
                commands.Release();
                UnityEngine.Object.DestroyImmediate(mesh);
                target.Release();
                UnityEngine.Object.DestroyImmediate(target);
            }
        }

        private static Color32[] RenderPipeline(Material material, string path)
        {
            var target = new RenderTexture(Size, Size, 24, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
            var commands = new CommandBuffer();
            try
            {
                target.Create();
                commands.SetRenderTarget(target);
                commands.ClearRenderTarget(true, true, Color.clear);
                commands.SetViewProjectionMatrices(Matrix4x4.identity, Matrix4x4.identity);
                commands.DrawProcedural(Matrix4x4.identity, material, 0, MeshTopology.Triangles, 3);
                Graphics.ExecuteCommandBuffer(commands);
                return Read(target, path);
            }
            finally
            {
                commands.Release();
                target.Release();
                UnityEngine.Object.DestroyImmediate(target);
            }
        }

        private static Color32[] Read(RenderTexture target, string path)
        {
            RenderTexture previous = RenderTexture.active;
            var pixels = new Texture2D(Size, Size, TextureFormat.RGBA32, false, true);
            try
            {
                RenderTexture.active = target;
                pixels.ReadPixels(new Rect(0, 0, Size, Size), 0, 0);
                pixels.Apply();
                File.WriteAllBytes(path, pixels.EncodeToPNG());
                return pixels.GetPixels32();
            }
            finally
            {
                RenderTexture.active = previous;
                UnityEngine.Object.DestroyImmediate(pixels);
            }
        }

        private static string Arg(string name)
        {
            string[] args = Environment.GetCommandLineArgs();
            for (int i = 0; i + 1 < args.Length; i++)
                if (args[i] == name) return args[i + 1];
            return null;
        }
    }
}
