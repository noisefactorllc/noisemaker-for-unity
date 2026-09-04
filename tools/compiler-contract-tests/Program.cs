using System;
using System.Reflection;
using Noisemaker.Hlsl.Compiler;

namespace CompilerContractTests
{
    static class Program
    {
        private static int _failures;

        static int Main()
        {
            TestMidiSelector();
            TestAudioSelector();
            TestInvalidSelectors();
            TestOrdinaryCallStillRejectsMixedArguments();
            TestUnknownKeywordOrder();
            TestRawEnum();
            TestClonePreservesSelectors();

            Console.WriteLine($"compiler contract tests: {(_failures == 0 ? "PASS" : "FAIL")} ({_failures} failures)");
            return _failures == 0 ? 0 : 1;
        }

        private static Node ParseExpression(string expression)
        {
            ProgramNode program = Parser.Parse(
                Lexer.Lex("search synth\nlet input = " + expression + "\n"),
                new EffectRegistry());
            return program.Vars[0].Expr;
        }

        private static void TestMidiSelector()
        {
            var midi = (MidiNode)ParseExpression(
                "midi(channel: 2, midiMode.triggerNote, 0.25, 0.75, 0.5, " +
                "name: \"Controller\", id: \"port-a\")");

            Check(((MemberNode)midi.Mode).Path[1] == "triggerNote", "MIDI dense mode");
            Check(((NumberNode)midi.Min).Value == 0.25, "MIDI dense min");
            Check(((NumberNode)midi.Max).Value == 0.75, "MIDI dense max");
            Check(((NumberNode)midi.Sensitivity).Value == 0.5, "MIDI dense sensitivity");
            Check(((StringNode)midi.Name).Value == "Controller", "MIDI name selector");
            Check(((StringNode)midi.Id).Value == "port-a", "MIDI id selector");
        }

        private static void TestAudioSelector()
        {
            var audio = (AudioNode)ParseExpression(
                "audio(band: audioBand.raw, 0.25, 0.75, channel: 2, " +
                "name: \"Interface\", id: \"device-b\")");

            Check(((MemberNode)audio.Band).Path[1] == "raw", "audio raw band");
            Check(((NumberNode)audio.Min).Value == 0.25, "audio dense min");
            Check(((NumberNode)audio.Max).Value == 0.75, "audio dense max");
            Check(((NumberNode)audio.Channel).Value == 2, "audio channel selector");
            Check(((StringNode)audio.Name).Value == "Interface", "audio name selector");
            Check(((StringNode)audio.Id).Value == "device-b", "audio id selector");
        }

        private static void TestInvalidSelectors()
        {
            string[] invalid =
            {
                "midi(1, id: \"port-a\")",
                "midi(1, midiMode.velocity, 0, 1, 1, \"Controller\")",
                "midi(1, bogus: 1)",
                "midi(1, name: Controller)",
                "midi(1, name: \"\")",
                "audio(audioBand.low, name: \"Interface\")",
                "audio(audioBand.low, channel: 1)",
                "audio(audioBand.low, id: \"device-b\")",
                "audio(audioBand.low, 0, 1, 2)",
                "audio(audioBand.low, bogus: 1)",
                "audio(audioBand.low, channel: 1, name: Interface)",
                "audio(audioBand.low, channel: 1, name: \"\")",
            };

            foreach (string source in invalid)
            {
                bool threw = false;
                try { ParseExpression(source); }
                catch (DslSyntaxError) { threw = true; }
                Check(threw, "invalid selector rejected: " + source);
            }
        }

        private static void TestUnknownKeywordOrder()
        {
            CheckError(
                "midi(1, zzz: 1, aaa: 2)",
                "midi() unknown parameter 'zzz' at line 2 col 13. Valid: channel, mode, min, max, sensitivity, name, id");
            CheckError(
                "audio(audioBand.low, zzz: 1, aaa: 2)",
                "audio() unknown parameter 'zzz' at line 2 col 13. Valid: band, min, max, channel, name, id");
        }

        private static void TestOrdinaryCallStillRejectsMixedArguments()
        {
            bool threw = false;
            try { ParseExpression("noise(1, scaleY: 2)"); }
            catch (DslSyntaxError) { threw = true; }
            Check(threw, "ordinary calls reject mixed positional and keyword arguments");
        }

        private static void TestRawEnum()
        {
            EnumNode raw = Enums.Std.Get("audioBand").Children.Get("raw");
            Check(raw != null && raw.HasValue && raw.Value == 4, "audioBand.raw == 4");
        }

        private static void TestClonePreservesSelectors()
        {
            MethodInfo clone = typeof(Validator).GetMethod(
                "Clone", BindingFlags.NonPublic | BindingFlags.Static);
            var midi = new MidiNode
            {
                Channel = new NumberNode { Value = 1 },
                Name = new StringNode { Value = "Controller" },
                Id = new StringNode { Value = "port-a" },
            };
            var audio = new AudioNode
            {
                Band = new MemberNode { Path = new System.Collections.Generic.List<string> { "audioBand", "raw" } },
                Channel = new NumberNode { Value = 2 },
                Name = new StringNode { Value = "Interface" },
                Id = new StringNode { Value = "device-b" },
            };

            var midiClone = (MidiNode)clone.Invoke(null, new object[] { midi });
            var audioClone = (AudioNode)clone.Invoke(null, new object[] { audio });

            Check(((StringNode)midiClone.Name).Value == "Controller", "cloned MIDI name selector");
            Check(((StringNode)midiClone.Id).Value == "port-a", "cloned MIDI id selector");
            Check(((NumberNode)audioClone.Channel).Value == 2, "cloned audio channel selector");
            Check(((StringNode)audioClone.Name).Value == "Interface", "cloned audio name selector");
            Check(((StringNode)audioClone.Id).Value == "device-b", "cloned audio id selector");
        }

        private static void CheckError(string source, string expected)
        {
            string message = null;
            try { ParseExpression(source); }
            catch (DslSyntaxError error) { message = error.Message; }
            Check(message == expected, "source-ordered diagnostic: " + source);
        }

        private static void Check(bool condition, string label)
        {
            if (condition) return;
            _failures++;
            Console.Error.WriteLine("FAIL: " + label);
        }
    }
}
