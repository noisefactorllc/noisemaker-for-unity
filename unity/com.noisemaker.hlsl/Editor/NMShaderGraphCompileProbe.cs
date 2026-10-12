using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace Noisemaker.Hlsl.Editor
{
    public static class NMShaderGraphCompileProbe
    {
        public static void Run()
        {
            string assetDirectory = Arg("-nmProbeDir");
            string reportPath = Arg("-nmProbeReport");
            string captureDirectory = Arg("-nmProbeCaptures");
            int expected = int.Parse(Arg("-nmProbeExpected") ?? "0");
            if (string.IsNullOrEmpty(assetDirectory) || string.IsNullOrEmpty(reportPath) ||
                string.IsNullOrEmpty(captureDirectory) || expected <= 0)
            {
                Debug.LogError("[NMSGProbe] -nmProbeDir, -nmProbeReport, -nmProbeCaptures and -nmProbeExpected are required");
                EditorApplication.Exit(2);
                return;
            }

            Directory.CreateDirectory(captureDirectory);
            string[] paths = Directory.GetFiles(assetDirectory, "*.shader")
                .Concat(Directory.GetFiles(assetDirectory, "*.shadergraph"))
                .OrderBy(p => p).ToArray();
            var report = new StringBuilder();
            int failures = 0;
            foreach (string path in paths)
            {
                bool graph = Path.GetExtension(path) == ".shadergraph";
                string name = Path.GetFileNameWithoutExtension(path) + (graph ? "-graph" : "-raw");
                Shader shader = AssetDatabase.LoadAssetAtPath<Shader>(path.Replace('\\', '/'));
                if (shader == null)
                {
                    report.AppendLine(name + "\tFAIL\tshader asset missing");
                    failures++;
                    continue;
                }

                try
                {
                    if (graph)
                        CheckGraphCall(path.Replace('\\', '/'), Path.GetFileNameWithoutExtension(path));
                    var material = new Material(shader);
                    try
                    {
                        ShaderUtil.CompilePass(material, 0, true);
                        var errors = ShaderUtil.GetShaderMessages(shader)
                            .Where(message => message.severity.ToString() == "Error").ToArray();
                        if (errors.Length > 0)
                        {
                            report.AppendLine(name + "\tFAIL\t" + errors[0].message.Replace('\n', ' '));
                            failures++;
                            continue;
                        }
                        if (!shader.isSupported)
                            throw new InvalidOperationException("shader unsupported on this graphics device");

                        material.SetTexture("_ProbeTex", Texture2D.whiteTexture);
                        material.SetTexture("_BaseMap", Texture2D.whiteTexture);
                        RenderCapture(material, Path.Combine(captureDirectory, name + ".png"), graph);
                        report.AppendLine(name + "\tPASS");
                    }
                    finally
                    {
                        UnityEngine.Object.DestroyImmediate(material);
                    }
                }
                catch (Exception error)
                {
                    report.AppendLine(name + "\tFAIL\t" + error.Message.Replace('\n', ' '));
                    failures++;
                }
            }

            File.WriteAllText(reportPath, report.ToString());
            Debug.Log($"[NMSGProbe] {paths.Length - failures}/{paths.Length} compiled and rendered, {failures} failed; report {reportPath}");
            EditorApplication.Exit(failures == 0 && paths.Length == expected ? 0 : 1);
        }

        private static void CheckGraphCall(string path, string stem)
        {
            var assembly = Assembly.Load("Unity.ShaderGraph.Editor");
            var importer = assembly.GetType("UnityEditor.ShaderGraph.ShaderGraphImporter", true);
            var method = importer.GetMethods(BindingFlags.Static | BindingFlags.NonPublic)
                .FirstOrDefault(item => item.Name == "GetShaderText" &&
                    item.GetParameters().Length == 4 && item.GetParameters()[3].IsOut);
            if (method == null)
                throw new InvalidOperationException("Shader Graph source inspection is unavailable");
            string source = (string)method.Invoke(null, new object[] { path, null, null, null });
            if (source == null || !source.Contains("NM_" + stem + "_float("))
                throw new InvalidOperationException("generated Shader Graph omits the Custom Function call");
        }

        private static void RenderCapture(Material material, string path, bool graph)
        {
            var target = new RenderTexture(4, 4, graph ? 24 : 0, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
            var pixels = new Texture2D(4, 4, TextureFormat.RGBA32, false, true);
            RenderTexture previous = RenderTexture.active;
            Mesh mesh = null;
            CommandBuffer commands = null;
            try
            {
                target.Create();
                if (graph)
                {
                    mesh = new Mesh
                    {
                        vertices = new[] {
                            new Vector3(-1, -1, 0), new Vector3(-1, 1, 0),
                            new Vector3(1, 1, 0), new Vector3(1, -1, 0)
                        },
                        uv = new[] {
                            new Vector2(0, 0), new Vector2(0, 1),
                            new Vector2(1, 1), new Vector2(1, 0)
                        },
                        triangles = new[] { 0, 1, 2, 0, 2, 3, 0, 2, 1, 0, 3, 2 }
                    };
                    mesh.RecalculateNormals();
                    commands = new CommandBuffer();
                    commands.SetRenderTarget(target);
                    commands.ClearRenderTarget(true, true, Color.clear);
                    commands.SetViewProjectionMatrices(Matrix4x4.identity, Matrix4x4.identity);
                    commands.DrawMesh(mesh, Matrix4x4.identity, material, 0, 0);
                    Graphics.ExecuteCommandBuffer(commands);
                }
                else
                {
                    Graphics.Blit(Texture2D.whiteTexture, target, material);
                }
                RenderTexture.active = target;
                pixels.ReadPixels(new Rect(0, 0, 4, 4), 0, 0);
                pixels.Apply();
                var colors = pixels.GetPixels();
                if (colors.Length != 16 || colors.Any(color =>
                    float.IsNaN(color.r) || float.IsNaN(color.g) ||
                    float.IsNaN(color.b) || float.IsNaN(color.a)))
                    throw new InvalidOperationException("render returned invalid pixels");
                if (graph && colors.All(color => color.a <= 0.5f))
                    throw new InvalidOperationException("Shader Graph rendered no opaque pixels");
                File.WriteAllBytes(path, pixels.EncodeToPNG());
            }
            finally
            {
                RenderTexture.active = previous;
                if (commands != null) commands.Release();
                if (mesh != null) UnityEngine.Object.DestroyImmediate(mesh);
                UnityEngine.Object.DestroyImmediate(pixels);
                target.Release();
                UnityEngine.Object.DestroyImmediate(target);
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
