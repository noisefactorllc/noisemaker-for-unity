// Console stand-in for NMParityRunner.CompileDslDumpBatchFromCommandLine —
// the Compiler assembly is pure C#, so graph parity needs no Unity editor.
// Usage: graphdump <effectsRoot> <manifest.tsv>   (lines: <dslPath>\t<outPath>)
using System;
using System.IO;
using Noisemaker.Hlsl.Compiler;
using Noisemaker.Hlsl.Compiler.Graph;

namespace GraphDump
{
    static class GraphDumpMain
    {
        static int Main(string[] args)
        {
            if (args.Length < 2)
            {
                Console.Error.WriteLine("usage: graphdump <effectsRoot> <manifest.tsv>");
                return 2;
            }
            EffectRegistry reg = EffectRegistry.LoadFromDirectory(args[0]);
            int ok = 0, fail = 0;
            foreach (string raw in File.ReadAllLines(args[1]))
            {
                string line = raw.Trim();
                if (line.Length == 0 || line.StartsWith("#")) continue;
                string[] parts = line.Split('\t');
                if (parts.Length < 2) continue;
                string dslPath = parts[0], outPath = parts[1];
                try
                {
                    RenderGraph graph = DslCompiler.Compile(File.ReadAllText(dslPath), reg);
                    File.WriteAllText(outPath, DslCompiler.ToNormalizedJson(graph));
                    ok++;
                }
                catch (Exception e)
                {
                    fail++;
                    Console.Error.WriteLine($"NM-GRAPH-FAIL {dslPath}: {e.Message}");
                }
            }
            Console.WriteLine($"graph-dump batch done: {ok} ok, {fail} fail");
            return fail > 0 ? 1 : 0;
        }
    }
}
