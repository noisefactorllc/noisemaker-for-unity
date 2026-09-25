using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using Noisemaker.Hlsl;
using Noisemaker.Hlsl.Compiler;
using Noisemaker.Hlsl.Compiler.Graph;

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
            TestMidiExpressionCompiler();
            TestMidiExpressionRuntime();
            TestDefaultAudioChannels();
            TestClonePreservesSelectors();
            TestNestedAutomationCompiler();
            TestAutomationCycleAndDepthGuards();
            TestNestedAutomationRuntime();
            TestAutomatedRepeatCount();
            TestExternalInputSelection();
            TestNestedAudioRequirements();
            TestInvalidAudioDoesNotCaptureNestedInput();
            TestAudioTaggedEffectRequirements();
            TestChainedVariableAlias();
            TestFilterAdjustAndExpiredEffects();
            TestOutputSurfaceRangeEnforcement();
            TestHlslIncludeDirectivesResolve();
            TestDiagnosticSourceColumnsAndLocations();
            TestStructuredLexerDiagnostics();
            TestStructuredParserDiagnostics();
            TestStructuredParserDiagnosticsP003Automation();
            TestStructuredParserDiagnosticsP004Search();
            TestStructuredParserDiagnosticsP005Output();
            TestStructuredParserDiagnosticsP006Subchain();
            TestSubchainArgumentDiagnosticsGAP027();
            TestStructuredParserDiagnosticsP007CallForm();
            TestStructuredParserDiagnosticsP001RemainingExpectations();
            TestNumberCoercionDiagnostics();
            TestValidCallForms();
            TestRenderLandscape3dFilteringDefines();
            TestGap004TexturePolicyContract();

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

        private static void TestMidiExpressionCompiler()
        {
            try
            {
                string[] modes = { "cc", "cc14", "nrpn", "pitchBend", "pressure", "polyPressure" };
                for (int i = 0; i < modes.Length; i++)
                {
                    JsonValue value = CompileProbe("automationProbe(amount: midi(2, midiMode." + modes[i] + ", nrpn: 42)).write(o0)")
                        .Passes[0].Uniforms["amount"].Object;
                    Check(value.Get("mode").AsNumber == i + 5, "expression MIDI enum " + modes[i]);
                }
                JsonValue zone = CompileProbe("let members = 3\nlet voice = midi(zone: midiZone.upper, members: members, mode: midiMode.pressure)\nautomationProbe(amount: voice).write(o0)")
                    .Passes[0].Uniforms["amount"].Object;
                Check(zone.Get("zone").AsNumber == 1 && zone.Get("members").AsNumber == 3 && !zone.Has("channel"),
                    "MPE selectors survive variables, cloning and graph serialization");
                foreach (string expression in new[] { "midi(17, midiMode.cc)", "midi(2, midiMode.cc14, cc: 32)", "midi(2, midiMode.nrpn)", "midi(zone: midiZone.lower, members: 0)" })
                {
                    JsonValue invalid = CompileProbe("automationProbe(amount: " + expression + ").write(o0)").Passes[0].Uniforms["amount"].Object;
                    Check(invalid.Get("_invalid").AsBool, "invalid MIDI selector fails closed");
                }
                string[] noteModes = { "noteChange", "gateNote", "gateVelocity", "triggerNote", "velocity" };
                foreach (string m in noteModes)
                {
                    foreach (int ch in new[] { 1, 16 })
                    {
                        JsonValue valid = CompileProbe("automationProbe(amount: midi(channel: " + ch + ", mode: midiMode." + m + ")).write(o0)").Passes[0].Uniforms["amount"].Object;
                        Check(valid.Get("channel").AsNumber == ch && valid.Get("_invalid") == null,
                            "legacy note mode " + m + " accepts static channel " + ch);
                    }
                    foreach (string badCh in new[] { "0", "17", "1.5", "true", "\"1\"", "osc()" })
                    {
                        bool failedClosed = false;
                        try
                        {
                            JsonValue invalid = CompileProbe("automationProbe(amount: midi(channel: " + badCh + ", mode: midiMode." + m + ")).write(o0)").Passes[0].Uniforms["amount"].Object;
                            failedClosed = invalid.Get("_invalid") != null && invalid.Get("_invalid").AsBool;
                        }
                        catch (Exception ex) when (ex.Message.Contains("ERR_COMPILATION_FAILED"))
                        {
                            failedClosed = true;
                        }
                        Check(failedClosed, "legacy note mode " + m + " rejects invalid channel " + badCh);
                    }
                }
                JsonValue audio = CompileProbe("automationProbe(amount: audio(audioBand.raw, channel:32)).write(o0)").Passes[0].Uniforms["amount"].Object;
                Check(audio.Get("channel").AsNumber == 32 && !audio.Get("_invalid").AsBool, "default audio channel32 compiles");
                audio = CompileProbe("automationProbe(amount: audio(audioBand.raw, channel:33)).write(o0)").Passes[0].Uniforms["amount"].Object;
                Check(audio.Get("_invalid").AsBool, "audio channels above32 fail closed");
            }
            catch (Exception e) { Check(false, "expression MIDI/audio compiler: " + e.Message); }
        }

        private static void TestMidiExpressionRuntime()
        {
            var midi = new MidiState();
            midi.HandleMessage(new byte[] { 0xb1, 1, 64 }, "a", "Controller");
            midi.HandleMessage(new byte[] { 0xb1, 33, 1 }, "a", "Controller");
            midi.HandleMessage(new byte[] { 0xb1, 99, 0 }, "a", "Controller");
            midi.HandleMessage(new byte[] { 0xb1, 98, 42 }, "a", "Controller");
            midi.HandleMessage(new byte[] { 0xb1, 6, 93 }, "a", "Controller");
            midi.HandleMessage(new byte[] { 0xb1, 38, 96 }, "a", "Controller");
            midi.HandleMessage(new byte[] { 0xe1, 0, 32 }, "a", "Controller");
            midi.HandleMessage(new byte[] { 0xd1, 90 }, "a", "Controller");
            midi.HandleMessage(new byte[] { 0x91, 60, 100 }, "a", "Controller", 1000);
            midi.HandleMessage(new byte[] { 0xa1, 60, 80 }, "a", "Controller");
            string[] modes = { "cc", "cc14", "nrpn", "pitchBend", "pressure", "polyPressure" };
            double[] expected = { 64.0/127, 8193.0/16383, 12000.0/16383, 4096.0/16383, 90.0/127, 80.0/127 };
            for (int i = 0; i < modes.Length; i++)
            {
                JsonValue value = CompileProbe("automationProbe(amount: midi(2, midiMode." + modes[i] + ", nrpn:42)).write(o0)")
                    .Passes[0].Uniforms["amount"].Object;
                CheckApprox(Automation.Evaluate(value,0,null,midi,null,1000), expected[i], 1e-12, "MIDI expression " + modes[i]);
                value = CompileProbe("automationProbe(amount: midi(zone:midiZone.lower, mode:midiMode." + modes[i] + ", nrpn:42)).write(o0)")
                    .Passes[0].Uniforms["amount"].Object;
                CheckApprox(Automation.Evaluate(value,0,null,midi,null,1000), expected[i], 1e-12, "MPE expression " + modes[i]);
            }
            foreach (int mode in new[] { 5, 6 })
            {
                var value = JsonValue.Parse("{\"type\":\"Midi\",\"mode\":" + mode + ",\"channel\":2,\"min\":0.2,\"max\":0.8,\"cc\":null}");
                CheckApprox(Automation.Evaluate(value,0,null,midi,null,1000), 0.2 + 0.6 * expected[mode - 5], 1e-12,
                    "null CC selects controller1 for mode " + mode);
                value.AsObject["cc"] = JsonValue.Of(true);
                Check(Automation.Evaluate(value,0,null,midi,null,1000) == 0.2, "boolean CC remains invalid");
                value.AsObject["cc"] = JsonValue.Of("1");
                Check(Automation.Evaluate(value,0,null,midi,null,1000) == 0.2, "string CC remains invalid");
            }
            midi.HandleMessage(new byte[] { 0xb1, 33, 127 }, "b", "Other");
            Check(midi.GetChannel(2).Cc14[1] == 127, "CC14 never pairs bytes from different ports");
            midi.DisconnectPort("b");
            Check(midi.GetChannel(2).Cc14[1] == 0 && midi.GetChannel(2).Cc[1] == 64,
                "disconnect clears only source-owned controller values");
            midi.HandleMessage(new byte[] { 0x91, 64, 127 }, "a", "Controller", 1001);
            midi.HandleMessage(new byte[] { 0x81, 64, 0 }, "a", "Controller");
            Check(midi.GetZoneVoice(0).Key == 60, "MPE falls back to older physically held note");
            midi.HandleMessage(new byte[] { 0xb0, 101, 0 }, "a", "Controller");
            midi.HandleMessage(new byte[] { 0xb0, 100, 6 }, "a", "Controller");
            midi.HandleMessage(new byte[] { 0xb0, 6, 3 }, "a", "Controller");
            MidiState port = midi.RegisterPort("a", "Controller");
            Check(port.LowerZoneMembers == 3 && port.UpperZoneMembers == 0 && midi.GetZoneVoice(0) == null,
                "MCM sets member count and clears reassigned notes");
            midi.HandleMessage(new byte[] { 0xb0, 6, 1 }, "a", "Controller");
            Check(port.LowerZoneMembers == 1, "MCM retains the active RPN6 transaction");
            midi.SetPortInventory(new[] { new MidiPortInfo { Id="a", Name="Controller" }, new MidiPortInfo { Id="unopened", Name="Controller" } });
            JsonValue selected = CompileProbe("automationProbe(amount:midi(2,midiMode.pressure,name:\"Controller\")).write(o0)").Passes[0].Uniforms["amount"].Object;
            Check(Automation.Evaluate(selected,0,null,midi,null,1000) == 0, "unopened duplicate MIDI name is ambiguous");
            var direct = new MidiState(); direct.GetChannel(2).NoteOn(72,100,1000);
            Check(direct.GetZoneVoice(0)?.Key == 72, "direct host NoteOn is visible to MPE");
            direct.GetChannel(2).NoteOff();
            Check(direct.GetZoneVoice(0) == null, "keyless NoteOff clears held notes");
        }

        private static void TestDefaultAudioChannels()
        {
            var audio = new AudioState();
            audio.RegisterDefaultChannels(32);
            audio.GetDefaultChannelState(32).SetRaw(-0.5);
            JsonValue value = CompileProbe("automationProbe(amount:audio(audioBand.raw,channel:32)).write(o0)").Passes[0].Uniforms["amount"].Object;
            Check(Automation.Evaluate(value,0,null,null,audio,1000) == 0.25, "default audio channel32 supplies raw sample");
            audio.SetRaw(1); audio.ResetAggregate();
            Check(Automation.Evaluate(value,0,null,null,audio,1000) == 0.25, "aggregate reset preserves selected audio");
            audio.DisconnectDefaultInput();
            Check(Automation.Evaluate(value,0,null,null,audio,1000) == 0, "disconnected default raw is unavailable");
            audio.RegisterDefaultChannels(32); audio.GetDefaultChannelState(32).SetRaw(0);
            Check(Automation.Evaluate(value,0,null,null,audio,1000) == 0.5, "ready zero differs from unavailable raw");
            AudioState removed = audio.GetDefaultChannelState(32); audio.RegisterDefaultChannels(2);
            Check(!removed.RawReady && audio.GetDefaultChannelState(32) == null, "shrunk default channels reset before removal");
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
                "midi() unknown parameter 'zzz' at line 2 col 13. Valid: channel, mode, min, max, sensitivity, name, id, cc, nrpn, zone, members");
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

        private static void TestNestedAutomationCompiler()
        {
            RenderGraph graph = CompileProbe(
                "let rate = midi(channel: 2, mode: midiMode.gateVelocity, " +
                "name: \"Controller\\nA\", id: 'port\\'a')\n" +
                "let floor = audio(band: audioBand.raw)\n" +
                "let carrier = osc(type: oscKind.saw, min: floor, speed: rate)\n" +
                "automationProbe(amount: carrier).write(o0)");
            JsonValue carrier = graph.Passes[0].Uniforms["amount"].Object;
            JsonValue speed = carrier.Get("speed");
            JsonValue floor = carrier.Get("min");

            Check(carrier.Get("type").AsString == "Oscillator", "outer oscillator compiled");
            Check(speed.Get("type").AsString == "Midi", "nested MIDI speed compiled");
            Check(floor.Get("type").AsString == "Audio", "nested audio bound compiled");
            Check(speed.Get("name").AsString == "Controller\nA", "MIDI name escape decoded");
            Check(speed.Get("id").AsString == "port'a", "single-quoted MIDI id escape decoded");
            Check(speed.Get("_varRef").AsString == "rate", "nested MIDI variable identity preserved");
            Check(floor.Get("_varRef").AsString == "floor", "nested audio variable identity preserved");
            Check(carrier.Get("_varRef").AsString == "carrier", "outer variable identity preserved");
            Check(carrier.Get("_ast")?.Get("type")?.AsString == "Oscillator", "outer automation AST preserved");
            Check(speed.Get("_ast")?.Get("loc")?.Get("line")?.AsNumber == 2,
                "nested automation source location preserved");

            string json = DslCompiler.ToNormalizedJson(graph);
            Check(json.Contains("\"amount\":{\"type\":\"Oscillator\""),
                "automation object survives normalized graph serialization");
            Check(json.Contains("\"_varRef\":\"rate\""),
                "normalized graph preserves nested variable identity");
        }

        private static void TestAutomationCycleAndDepthGuards()
        {
            EffectRegistry reg = ProbeRegistry();
            ProgramNode cycleAst = Parser.Parse(Lexer.Lex(
                "search synth\n" +
                "let a = osc(speed: b)\n" +
                "let b = osc(speed: a)\n" +
                "automationProbe(amount: b).write(o0)\n"), reg);
            ValidateResult cycle = Validator.Validate(cycleAst, reg);
            Check(cycle.Diagnostics.Exists(d => d.Message.Contains("Automation cycle detected")),
                "automation cycle diagnosed without recursion");

            string source = "search synth\nlet rate9 = osc()\n";
            for (int n = 8; n >= 1; n--)
                source += "let rate" + n + " = osc(speed: rate" + (n + 1) + ")\n";
            source += "let carrier = osc(speed: rate1)\n" +
                "automationProbe(amount: carrier).write(o0)\n";
            ValidateResult deep = Validator.Validate(Parser.Parse(Lexer.Lex(source), reg), reg);
            Check(deep.Diagnostics.Exists(d => d.Message.Contains("maximum depth of 8")),
                "automation nesting beyond eight levels diagnosed");
        }

        private static void TestNestedAutomationRuntime()
        {
            JsonValue value = CompileProbe(
                "let rate = osc(type: oscKind.sine)\n" +
                "let carrier = osc(type: oscKind.saw, speed: rate)\n" +
                "automationProbe(amount: carrier).write(o0)")
                .Passes[0].Uniforms["amount"].Object;
            var consumer = new UniformSpec { Min = 10, Max = 20 };
            double first = Automation.Evaluate(value, 0.61, consumer, null, null, 1000);
            double repeated = Automation.Evaluate(value, 0.61, consumer, null, null, 1000);
            Check(double.IsFinite(first), "nested oscillator result is finite");
            Check(first == repeated, "nested oscillator seeking is deterministic");
            Check(first >= 10 && first <= 20, "nested oscillator scales to consumer range");

            double quarter = Automation.Evaluate(value, 0.25, null, null, null, 1000);
            double threeQuarter = Automation.Evaluate(value, 0.75, null, null, null, 1000);
            CheckApprox(quarter, PositiveModulo(-20 / (Math.PI * 2), 1), 1e-9,
                "nested sine rate integrates through negative motion");
            CheckApprox(threeQuarter, PositiveModulo(20 / (Math.PI * 2), 1), 1e-9,
                "nested sine rate integrates through positive motion");

            JsonValue midiCarrier = CompileProbe(
                "let rate = midi(channel: 1, mode: midiMode.gateVelocity)\n" +
                "let carrier = osc(type: oscKind.saw, speed: rate)\n" +
                "automationProbe(amount: carrier).write(o0)")
                .Passes[0].Uniforms["amount"].Object;
            var midi = new MidiState();
            midi.GetChannel(1).Gate = 1;
            midi.GetChannel(1).Velocity = 127;
            CheckApprox(Automation.Evaluate(midiCarrier, 0.0125, null, midi, null, 1000),
                0.25, 1e-9, "MIDI can drive oscillator rate forward");
            midi.GetChannel(1).Velocity = 0;
            CheckApprox(Automation.Evaluate(midiCarrier, 0.0125, null, midi, null, 1000),
                0.75, 1e-9, "MIDI can drive oscillator rate backward");

            JsonValue audioCarrier = CompileProbe(
                "let rate = audio(band: audioBand.raw)\n" +
                "let carrier = osc(type: oscKind.saw, speed: rate)\n" +
                "automationProbe(amount: carrier).write(o0)")
                .Passes[0].Uniforms["amount"].Object;
            var audio = new AudioState();
            audio.SetRaw(1);
            CheckApprox(Automation.Evaluate(audioCarrier, 0.0125, null, null, audio, 1000),
                0.25, 1e-9, "audio can drive oscillator rate forward");
            audio.SetRaw(-1);
            CheckApprox(Automation.Evaluate(audioCarrier, 0.0125, null, null, audio, 1000),
                0.75, 1e-9, "audio can drive oscillator rate backward");

            JsonValue dynamicRange = CompileProbe(
                "let shape = osc(type: oscKind.sine)\n" +
                "let rate = midi(channel: 1, mode: midiMode.gateVelocity, " +
                "min: shape, max: shape)\n" +
                "let carrier = osc(type: oscKind.saw, speed: rate)\n" +
                "automationProbe(amount: carrier).write(o0)")
                .Passes[0].Uniforms["amount"].Object;
            CheckApprox(Automation.Evaluate(dynamicRange, 0.25, null,
                    new MidiState(), null, 1000),
                PositiveModulo(-20 / (Math.PI * 2), 1), 1e-8,
                "dynamic MIDI ranges are integrated instead of endpoint-sampled");
        }

        private static void TestExternalInputSelection()
        {
            JsonValue selectedMidi = CompileProbe(
                "automationProbe(amount: midi(channel: 1, mode: midiMode.gateVelocity, " +
                "name: \"Controller\", id: \"port-a\")).write(o0)")
                .Passes[0].Uniforms["amount"].Object;
            var midi = new MidiState();
            midi.GetChannel(1).Gate = 1;
            midi.GetChannel(1).Velocity = 127;
            MidiState port = midi.RegisterPort("port-a", "Controller");
            port.GetChannel(1).Gate = 1;
            port.GetChannel(1).Key = 64;
            port.GetChannel(1).Velocity = 64;
            CheckApprox(Automation.Evaluate(selectedMidi, 0, null, midi, null, 1000),
                64.0 / 127.0, 1e-9, "MIDI id selects isolated port state");

            JsonValue selectedAudio = CompileProbe(
                "automationProbe(amount: audio(band: audioBand.mid, channel: 2, " +
                "name: \"Interface\", id: \"device-b\")).write(o0)")
                .Passes[0].Uniforms["amount"].Object;
            var audio = new AudioState();
            audio.Mid = 0.9;
            audio.RegisterDevice("device-b", "Interface", 2);
            audio.SetChannelValues("device-b", 2, 0.1, 0.4, 0.8, 0.5);
            CheckApprox(Automation.Evaluate(selectedAudio, 0, null, null, audio, 1000),
                0.4, 1e-9, "audio id and channel select isolated device state");

            midi.RegisterPort("port-b", "Controller").GetChannel(1).Key = 127;
            JsonValue nameOnlyMidi = CompileProbe(
                "automationProbe(amount: midi(channel: 1, mode: midiMode.noteChange, " +
                "name: \"Controller\")).write(o0)")
                .Passes[0].Uniforms["amount"].Object;
            CheckApprox(Automation.Evaluate(nameOnlyMidi, 0, null, midi, null, 1000),
                0, 0, "ambiguous MIDI names fail closed");

            audio.RegisterDevice("device-c", "Interface", 2);
            audio.SetChannelValues("device-c", 2, mid: 0.7);
            JsonValue nameOnlyAudio = CompileProbe(
                "automationProbe(amount: audio(band: audioBand.mid, channel: 2, " +
                "name: \"Interface\")).write(o0)")
                .Passes[0].Uniforms["amount"].Object;
            CheckApprox(Automation.Evaluate(nameOnlyAudio, 0, null, null, audio, 1000),
                0, 0, "ambiguous audio names fail closed");

            audio.SetChannelValues("device-b", 2, raw: 0.75);
            audio.SetDeviceRawUnavailable("device-b");
            JsonValue rawAudio = CompileProbe(
                "automationProbe(amount: audio(band: audioBand.raw, channel: 2, " +
                "name: \"Interface\", id: \"device-b\")).write(o0)")
                .Passes[0].Uniforms["amount"].Object;
            CheckApprox(Automation.Evaluate(rawAudio, 0, null, null, audio, 1000),
                0, 0, "selected raw audio reports unavailable capture");
        }

        private static void TestAutomatedRepeatCount()
        {
            Pass pass = CompileProbe(
                "automationProbe(amount: osc(type: oscKind.sine)).write(o0)")
                .Passes[0];
            pass.Uniforms["iterations"] = pass.Uniforms["amount"];
            pass.UniformSpecs["iterations"] = new UniformSpec { Min = 1, Max = 8 };
            pass.Repeat = Repeat.FromUniform("iterations");

            Check(Automation.ResolveRepeatCount(pass, 0.5, null, null, null, 1000) == 8,
                "automation resolves before pass repeat count");
            Check(Automation.ResolveRepeatCount(pass, 0.5, _ => 3, null, null, 1000) == 3,
                "live global value overrides automated repeat count");
        }

        private static void TestNestedAudioRequirements()
        {
            RenderGraph graph = CompileProbe(
                "let selected = audio(band: audioBand.raw, channel: 2, " +
                "name: \"Interface\", id: \"device-b\")\n" +
                "let legacy = audio(band: audioBand.low)\n" +
                "let carrier = osc(min: selected, max: legacy)\n" +
                "automationProbe(amount: carrier).write(o0)");
            AudioInputRequirements req = Automation.GetAudioInputRequirements(graph.Passes);
            Check(req.NeedsLegacy, "nested legacy audio capture discovered");
            Check(!req.NeedsLegacyRaw, "legacy low-band capture does not request raw samples");
            Check(req.Selected.Count == 1, "nested selected audio capture deduplicated");
            Check(req.Selected[0].Id == "device-b" && req.Selected[0].Name == "Interface" &&
                req.Selected[0].Channel == 2 && req.Selected[0].NeedsRaw,
                "nested selected raw-audio requirement preserved");
        }

        private static void TestInvalidAudioDoesNotCaptureNestedInput()
        {
            JsonValue inner = JsonValue.Parse(
                "{\"type\":\"Audio\",\"band\":0,\"min\":0,\"max\":1," +
                "\"channel\":1,\"name\":\"Inner Interface\",\"id\":\"inner-id\"}");
            JsonValue invalidOuter = JsonValue.Parse(
                "{\"type\":\"Audio\",\"band\":0,\"min\":0,\"max\":1,\"_invalid\":true}");
            invalidOuter.AsObject["min"] = inner;
            var pass = new Pass();
            pass.Uniforms["amount"] = UniformValue.OfObject(invalidOuter);
            AudioInputRequirements req = Automation.GetAudioInputRequirements(
                new[] { pass });

            var audio = new AudioState();
            audio.RegisterDevice("inner-id", "Inner Interface", 1);
            audio.SetChannelValues("inner-id", 1, low: 0.8);
            Check(req.Selected.Count == 0,
                "invalid outer audio does not request nested capture");
            CheckApprox(Automation.Evaluate(invalidOuter, 0.5, null, null, audio, 1000),
                0, 0, "invalid outer audio with automated min fails closed");
        }

        private static void TestAudioTaggedEffectRequirements()
        {
            var registry = new EffectRegistry();
            registry.Register(JsonValue.Parse(
                "{\"name\":\"Audio Meter\",\"namespace\":\"user\"," +
                "\"func\":\"audioMeter\",\"starter\":true,\"tags\":[\"audio\"]," +
                "\"globals\":{},\"passes\":[{\"name\":\"render\"," +
                "\"program\":\"audioMeter\",\"inputs\":{},\"outputs\":{" +
                "\"fragColor\":\"outputTex\"}}],\"textures\":{}}"));
            RenderGraph graph = DslCompiler.Compile(
                "search user\naudioMeter().write(o0)\nrender(o0)\n", registry);
            AudioInputRequirements req = Automation.GetAudioInputRequirements(graph.Passes);
            Check(req.NeedsLegacy,
                "custom audio-tagged effects request legacy capture without audio() uniforms");

            RenderGraph precompiled = GraphLoader.FromJson(
                "{\"passes\":[{\"effectKey\":\"synth.scope\"," +
                "\"namespace\":\"synth\",\"func\":\"scope\",\"uniforms\":{}}]}");
            req = Automation.GetAudioInputRequirements(precompiled.Passes);
            Check(req.NeedsLegacy,
                "precompiled bundled audio effect retains capture metadata without a registry");
        }

        private static void TestChainedVariableAlias()
        {
            try
            {
                var reg = new EffectRegistry();
                reg.Register(JsonValue.Parse(
                    "{\"name\":\"Noise\",\"namespace\":\"synth\"," +
                    "\"func\":\"noise\",\"starter\":true,\"globals\":{}," +
                    "\"passes\":[{\"name\":\"render\",\"program\":\"noise\"," +
                    "\"inputs\":{},\"outputs\":{\"fragColor\":\"outputTex\"}}],\"textures\":{}}"));
                reg.Register(JsonValue.Parse(
                    "{\"name\":\"Rotate\",\"namespace\":\"filter\"," +
                    "\"func\":\"rotate\",\"starter\":false,\"globals\":{" +
                    "\"angle\":{\"type\":\"float\",\"default\":0,\"uniform\":\"angle\"}," +
                    "\"speed\":{\"type\":\"float\",\"default\":0,\"uniform\":\"speed\"}}," +
                    "\"passes\":[{\"name\":\"render\",\"program\":\"rotate\"," +
                    "\"inputs\":{\"tex\":\"inputTex\"},\"outputs\":{\"fragColor\":\"outputTex\"}}],\"textures\":{}}"));
                string source = "search synth, filter\nlet gen = noise()\nlet eff = rotate(1, 0.1)\ngen().eff().write(o0)\nrender(o0)\n";
                RenderGraph graph = DslCompiler.Compile(source, reg);
                Check(graph.Passes.Count == 3, "chained variable alias emits 3 passes");
                Check(graph.Passes[0].Id == "node_0_pass_0", "pass 0 is node_0_pass_0");
                Check(graph.Passes[1].Id == "node_1_pass_0", "pass 1 is node_1_pass_0");
                Check(graph.Passes[2].Id == "node_2_write_blit", "terminal pass is node_2_write_blit");
                Check(graph.Passes[2].Program == "blit", "terminal program is blit");
                Check(graph.Passes[2].PassType == PassType.Blit, "terminal passType is blit");
                Check(graph.Passes[2].Inputs.TryGetValue("src", out string src) && src == "node_1_out", "terminal read is node_1_out");
                Check(graph.Passes[2].Outputs.TryGetValue("color", out string color) && color == "global_o0", "terminal write is global_o0");
            }
            catch (Exception ex)
            {
                Check(false, "chained variable alias: " + ex.Message);
            }
        }

        private static void TestFilterAdjustAndExpiredEffects()
        {
            try
            {
                string effectsDir = Path.Combine(Directory.GetCurrentDirectory(), "unity", "com.noisemaker.hlsl", "Effects");
                if (!Directory.Exists(effectsDir))
                {
                    effectsDir = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "unity", "com.noisemaker.hlsl", "Effects"));
                }
                var reg = EffectRegistry.LoadFromDirectory(effectsDir);

                // filter.adjust should be present and compile
                string source = "search synth, filter\nnoise().adjust(rotation: 45).write(o0)\nrender(o0)\n";
                RenderGraph graph = DslCompiler.Compile(source, reg);
                bool hasAdjust = false;
                foreach (var p in graph.Passes)
                {
                    if (p.EffectKey == "filter.adjust") hasAdjust = true;
                }
                Check(hasAdjust, "filter.adjust resolves in compiled graph");

                // expired effects: bc, colorspace, hs should produce Unknown effect error (diagnostic S001)
                string[] expired = { "bc", "colorspace", "hs" };
                foreach (string exp in expired)
                {
                    string badSource = "search synth, filter\nnoise()." + exp + "().write(o0)\nrender(o0)\n";
                    var tokens = Lexer.Lex(badSource);
                    var program = Parser.Parse(tokens, reg);
                    var result = Validator.Validate(program, reg);
                    bool hasUnknownDiagnostic = false;
                    foreach (var diag in result.Diagnostics)
                    {
                        if (diag.Code == "S001") hasUnknownDiagnostic = true;
                    }
                    Check(hasUnknownDiagnostic, "expired effect " + exp + " produces diagnostic S001");
                }
            }
            catch (Exception ex)
            {
                Check(false, "TestFilterAdjustAndExpiredEffects: " + ex.Message);
            }
        }

        private static void TestOutputSurfaceRangeEnforcement()
        {
            try
            {
                // valid boundaries
                var toks = Lexer.Lex("o0 o7 s3 output0");
                Check(toks.Count == 5, "token count for boundary test");
                Check(toks[0].Type == TokenType.OUTPUT_REF && toks[0].Lexeme == "o0", "o0 is OUTPUT_REF");
                Check(toks[1].Type == TokenType.OUTPUT_REF && toks[1].Lexeme == "o7", "o7 is OUTPUT_REF");
                Check(toks[2].Type == TokenType.SOURCE_REF && toks[2].Lexeme == "s3", "s3 is SOURCE_REF");

                // out-of-range references throw DslSyntaxError
                var cases = new (string src, string expected)[]
                {
                    ("render(o8)", "Output surface reference 'o8' is out of range; expected o0-o7 at line 1 col 8"),
                    ("read(o99).write(o0)", "Output surface reference 'o99' is out of range; expected o0-o7 at line 1 col 6"),
                    ("read(o0).write(o10)", "Output surface reference 'o10' is out of range; expected o0-o7 at line 1 col 16"),
                };
                foreach (var (src, expected) in cases)
                {
                    bool threw = false;
                    try
                    {
                        Lexer.Lex(src);
                    }
                    catch (DslSyntaxError ex)
                    {
                        threw = true;
                        Check(ex.Message == expected, "error message for " + src + " matches: " + ex.Message);
                    }
                    Check(threw, "syntax error thrown for " + src);
                }

                // member segments foo.o8 and foo.o99 are allowed
                var memberToks = Lexer.Lex("foo.o0 foo.o7 foo.o8 foo.o99");
                var outputRefs = new System.Collections.Generic.List<string>();
                foreach (var t in memberToks)
                {
                    if (t.Type == TokenType.OUTPUT_REF) outputRefs.Add(t.Lexeme);
                }
                Check(outputRefs.Count == 4 && outputRefs[0] == "o0" && outputRefs[1] == "o7" && outputRefs[2] == "o8" && outputRefs[3] == "o99",
                    "member segments allow o8/o99");

                // other surface reference families preserve multi-digit numbers
                var otherToks = Lexer.Lex("s99 vol99 geo99 xyz99 vel99 rgba99 mesh99");
                Check(otherToks.Count == 8, "7 ref tokens + EOF");
                Check(otherToks[0].Type == TokenType.SOURCE_REF && otherToks[0].Lexeme == "s99", "s99");
                Check(otherToks[1].Type == TokenType.VOL_REF && otherToks[1].Lexeme == "vol99", "vol99");
                Check(otherToks[2].Type == TokenType.GEO_REF && otherToks[2].Lexeme == "geo99", "geo99");
                Check(otherToks[3].Type == TokenType.XYZ_REF && otherToks[3].Lexeme == "xyz99", "xyz99");
                Check(otherToks[4].Type == TokenType.VEL_REF && otherToks[4].Lexeme == "vel99", "vel99");
                Check(otherToks[5].Type == TokenType.RGBA_REF && otherToks[5].Lexeme == "rgba99", "rgba99");
                Check(otherToks[6].Type == TokenType.MESH_REF && otherToks[6].Lexeme == "mesh99", "mesh99");
            }
            catch (Exception ex)
            {
                Check(false, "TestOutputSurfaceRangeEnforcement: " + ex.Message);
            }
        }

        private static void TestHlslIncludeDirectivesResolve()
        {
            try
            {
                string packageDir = Path.Combine(Directory.GetCurrentDirectory(), "unity", "com.noisemaker.hlsl");
                if (!Directory.Exists(packageDir))
                {
                    packageDir = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "unity", "com.noisemaker.hlsl"));
                }
                string[] hlslFiles = Directory.GetFiles(packageDir, "*.hlsl", SearchOption.AllDirectories);
                string[] shaderFiles = Directory.GetFiles(packageDir, "*.shader", SearchOption.AllDirectories);
                var allFiles = new System.Collections.Generic.List<string>(hlslFiles);
                allFiles.AddRange(shaderFiles);

                int checkedIncludes = 0;
                foreach (string file in allFiles)
                {
                    string fileDir = Path.GetDirectoryName(file);
                    string[] lines = File.ReadAllLines(file);
                    foreach (string rawLine in lines)
                    {
                        string line = rawLine.Trim();
                        if (!line.StartsWith("#include")) continue;
                        int firstQuote = line.IndexOf('"');
                        int lastQuote = line.LastIndexOf('"');
                        if (firstQuote >= 0 && lastQuote > firstQuote)
                        {
                            string relPath = line.Substring(firstQuote + 1, lastQuote - firstQuote - 1);
                            if (relPath.StartsWith("Packages/") || relPath.StartsWith("Unity") || !relPath.Contains("/"))
                                continue;
                            string fullTarget = Path.GetFullPath(Path.Combine(fileDir, relPath));
                            Check(File.Exists(fullTarget), "include in " + Path.GetFileName(file) + " resolves to: " + relPath);
                            checkedIncludes++;
                        }
                    }
                }
                Check(checkedIncludes > 0, "verified " + checkedIncludes + " relative HLSL include directives");
            }
            catch (Exception ex)
            {
                Check(false, "TestHlslIncludeDirectivesResolve: " + ex.Message);
            }
        }

        private static void TestDiagnosticSourceColumnsAndLocations()
        {
            try
            {
                string effectsDir = Path.Combine(Directory.GetCurrentDirectory(), "unity", "com.noisemaker.hlsl", "Effects");
                if (!Directory.Exists(effectsDir))
                {
                    effectsDir = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "unity", "com.noisemaker.hlsl", "Effects"));
                }
                var reg = EffectRegistry.LoadFromDirectory(effectsDir);
                string source = "search synth\n  read(123).write(o0)";
                var program = Parser.Parse(Lexer.Lex(source), reg);
                var result = Validator.Validate(program, reg);
                Check(result.Diagnostics.Count >= 2, "has at least 2 diagnostics for read(123).write(o0)");
                var readDiag = result.Diagnostics[0];
                Check(readDiag.Code == "S001", "first diag is S001");
                Check(readDiag.Location != null, "first diag has location");
                Check(readDiag.Location.Line == 2 && readDiag.Location.Column == 3,
                    $"read diag location line 2 col 3 (got {readDiag.Location?.Line}, {readDiag.Location?.Column})");
                Check(readDiag.Location.ToString() == "(2:3)", "diagnostic location ToString formatting");
                Check(readDiag.Line == 2 && readDiag.Column == 3, "read diag flat line/column match");

                var writeDiag = result.Diagnostics[1];
                Check(writeDiag.Code == "S005", "second diag is S005");
                Check(writeDiag.Location != null, "second diag has location");
                Check(writeDiag.Location.Line == 2 && writeDiag.Location.Column == 13,
                    $"write diag location line 2 col 13 (got {writeDiag.Location?.Line}, {writeDiag.Location?.Column})");

                // Test explicit LocColumn override on AST node
                var chainStmt = (ChainStatementNode)program.Plans[0];
                chainStmt.Chain[0].LocColumn = 9;
                var result2 = Validator.Validate(program, reg);
                Check(result2.Diagnostics[0].Column == 9, "diag column overridden to 9");
                Check(result2.Diagnostics[0].Location != null && result2.Diagnostics[0].Location.Column == 9,
                    "diag location column overridden to 9");

                // Test unlocated node does not invent location
                string missingSource = "search synth\n  missing().write(o0)";
                var missingProg = Parser.Parse(Lexer.Lex(missingSource), reg);
                var missingResult = Validator.Validate(missingProg, reg);
                Diagnostic missingDiag = null;
                foreach (var d in missingResult.Diagnostics)
                {
                    if (d.Identifier == "missing") { missingDiag = d; break; }
                }
                Check(missingDiag != null, "missing diagnostic found");
                Check(missingDiag.Code == "S001", "missing diagnostic code S001");
                Check(missingDiag.Location == null, "unlocated diagnostic has no Location");
                Check(missingDiag.Line == null, "unlocated diagnostic has no Line");
                Check(missingDiag.Column == null, "unlocated diagnostic has no Column");
            }
            catch (Exception ex)
            {
                Check(false, "TestDiagnosticSourceColumnsAndLocations: " + ex.Message);
            }
        }

        private static void TestStructuredLexerDiagnostics()
        {
            try
            {
                var cases = new (string name, string source, string code, string message, int line, int column, int start, int end)[]
                {
                    (
                        "unexpected character after CRLF, tab, and UTF-16 text",
                        "// 😀\r\n\t@",
                        "L001",
                        "Unexpected character '@' at line 2 col 2",
                        2, 2, 8, 9
                    ),
                    (
                        "unterminated double-quoted string at EOF",
                        "\"abc",
                        "L002",
                        "Unterminated string literal at line 1 col 1",
                        1, 1, 0, 4
                    ),
                    (
                        "unterminated single-quoted string at LF",
                        " 'abc\nnext",
                        "L002",
                        "Unterminated string literal at line 1 col 2",
                        1, 2, 1, 5
                    ),
                    (
                        "unterminated triple-quoted string across lines",
                        "\n  \"\"\"a\nb",
                        "L002",
                        "Unterminated triple-quoted string at line 2 col 3",
                        2, 3, 3, 9
                    ),
                    (
                        "unterminated block comment across lines",
                        "\n /* a\nb",
                        "L003",
                        "Unterminated comment at line 2 col 2",
                        2, 2, 2, 8
                    ),
                    (
                        "out-of-range output reference",
                        "search synth\nrender(o99)",
                        "L004",
                        "Output surface reference 'o99' is out of range; expected o0-o7 at line 2 col 8",
                        2, 8, 20, 23
                    ),
                    (
                        "UTF-16 columns after a string",
                        "\"😀\" @",
                        "L001",
                        "Unexpected character '@' at line 1 col 6",
                        1, 6, 5, 6
                    ),
                    (
                        "source coordinates after a multiline function token",
                        "() => (1\n + 2), @",
                        "L001",
                        "Unexpected character '@' at line 1 col 17",
                        2, 8, 16, 17
                    ),
                    (
                        "source coordinates after an escaped LF in a string",
                        "\"a\\\nb\" @",
                        "L001",
                        "Unexpected character '@' at line 1 col 8",
                        2, 4, 7, 8
                    )
                };

                foreach (var tc in cases)
                {
                    // Test direct Lexer.Lex
                    try
                    {
                        Lexer.Lex(tc.source);
                        Check(false, $"{tc.name}: expected DslSyntaxError from Lexer.Lex");
                    }
                    catch (DslSyntaxError ex)
                    {
                        Check(ex.Message == tc.message, $"{tc.name}: message matches (expected '{tc.message}', got '{ex.Message}')");
                        Check(ex.Diagnostic != null, $"{tc.name}: diagnostic payload present");
                        if (ex.Diagnostic != null)
                        {
                            var d = ex.Diagnostic;
                            Check(d.Code == tc.code, $"{tc.name}: code {tc.code} (got {d.Code})");
                            Check(d.Stage == "lexer", $"{tc.name}: stage lexer (got {d.Stage})");
                            Check(d.Severity == DiagnosticSeverity.Error, $"{tc.name}: severity Error");
                            Check(d.SeverityString == "error", $"{tc.name}: severityString error");
                            Check(d.Message == tc.message, $"{tc.name}: diag message matches");
                            Check(d.Location != null, $"{tc.name}: location present");
                            if (d.Location != null)
                            {
                                Check(d.Location.Line == tc.line && d.Location.Column == tc.column,
                                    $"{tc.name}: location ({tc.line}:{tc.column}) (got ({d.Location.Line}:{d.Location.Column}))");
                            }
                            Check(d.Span != null, $"{tc.name}: span present");
                            if (d.Span != null)
                            {
                                Check(d.Span.Start == tc.start && d.Span.End == tc.end,
                                    $"{tc.name}: span ({tc.start}:{tc.end}) (got ({d.Span.Start}:{d.Span.End}))");
                                Check(d.Span.ToString() == $"({tc.start}:{tc.end})",
                                    $"{tc.name}: span ToString ({tc.start}:{tc.end})");
                            }
                        }
                    }

                    // Test via DslCompiler.Compile (should propagate DslSyntaxError)
                    try
                    {
                        DslCompiler.Compile(tc.source, new EffectRegistry());
                        Check(false, $"{tc.name}: expected DslSyntaxError from DslCompiler.Compile");
                    }
                    catch (DslSyntaxError ex)
                    {
                        Check(ex.Diagnostic != null && ex.Diagnostic.Code == tc.code,
                            $"{tc.name}: compiler propagated DslSyntaxError with code {tc.code}");
                    }
                    catch (Exception ex)
                    {
                        Check(false, $"{tc.name}: unexpected exception type {ex.GetType().Name}");
                    }
                }

                // Successful token stream unchanged
                var tokens = Lexer.Lex("/*x*/\nfoo.o99 \"😀\"");
                Check(tokens.Count == 6, "tokens count is 6");
                Check(tokens[0].Type == TokenType.COMMENT && tokens[0].Lexeme == "/*x*/" && tokens[0].Line == 1 && tokens[0].Col == 1, "tok 0 COMMENT");
                Check(tokens[1].Type == TokenType.IDENT && tokens[1].Lexeme == "foo" && tokens[1].Line == 2 && tokens[1].Col == 1, "tok 1 IDENT");
                Check(tokens[2].Type == TokenType.DOT && tokens[2].Lexeme == "." && tokens[2].Line == 2 && tokens[2].Col == 4, "tok 2 DOT");
                Check(tokens[3].Type == TokenType.OUTPUT_REF && tokens[3].Lexeme == "o99" && tokens[3].Line == 2 && tokens[3].Col == 5, "tok 3 OUTPUT_REF");
                Check(tokens[4].Type == TokenType.STRING && tokens[4].Lexeme == "😀" && tokens[4].Line == 2 && tokens[4].Col == 9, "tok 4 STRING");
                Check(tokens[5].Type == TokenType.EOF && tokens[5].Lexeme == "" && tokens[5].Line == 2 && tokens[5].Col == 13, "tok 5 EOF");

                // Diagnostic table metadata lookups
                Check(DiagnosticTable.Stage("L001") == "lexer", "diag stage L001");
                Check(DiagnosticTable.Stage("P001") == "parser", "diag stage P001");
                Check(DiagnosticTable.Stage("S001") == "semantic", "diag stage S001");
                Check(DiagnosticTable.Stage("R001") == "runtime", "diag stage R001");
                Check(DiagnosticTable.Severity("L001") == DiagnosticSeverity.Error, "diag severity L001 error");
                Check(DiagnosticTable.Severity("S002") == DiagnosticSeverity.Warning, "diag severity S002 warning");
                Check(DiagnosticTable.DefaultMessage("L003") == "Unterminated comment", "diag default message L003");
                Check(DiagnosticTable.DefaultMessage("L004") == "Output surface reference out of range", "diag default message L004");
            }
            catch (Exception ex)
            {
                Check(false, "TestStructuredLexerDiagnostics: " + ex.Message);
            }
        }

        private static void TestStructuredParserDiagnostics()
        {
            var cases = new (string name, string source, string code, string message, int line, int column)[]
            {
                ("opening parenthesis", "search synth\nrender o0", "P001", "Expect '(' at line 2 col 8", 2, 8),
                ("closing parenthesis at EOF", "search synth\nrender(o0", "P002", "Expect ')' at line 2 col 10", 2, 10),
                ("identifier", "search synth\nlet = 1", "P001", "Expected identifier at line 2 col 5", 2, 5),
                ("assignment sign", "search synth\nlet x 1", "P001", "Expect '=' at line 2 col 7", 2, 7),
                ("block opening", "search synth\nif(true) return 1", "P001", "Expect '{' at line 2 col 10", 2, 10),
                ("end of input", "search synth\nrender(o0) xyz", "P001", "Expected end of input at line 2 col 12", 2, 12),
                ("call closing parenthesis", "search synth\nfoo(1", "P002", "Expect ')' at line 2 col 6", 2, 6),
                ("write3d separator", "search synth\nfoo().write3d(tex3d0 geo0)", "P001", "Expect ',' between tex3d and geo in write3d() at line 2 col 22", 2, 22),
                ("CRLF and tab", "// 😀\r\nsearch synth\r\n\trender(o0", "P002", "Expect ')' at line 3 col 11", 3, 11),
                ("UTF-16 column", "search synth\nlet x = \"😀\"; render o0", "P001", "Expect '(' at line 2 col 22", 2, 22),
            };

            foreach (var c in cases)
            {
                // Test via Parser.Parse(Lexer.Lex(source))
                try
                {
                    Parser.Parse(Lexer.Lex(c.source));
                    Check(false, "TestStructuredParserDiagnostics: expected parse error for " + c.name);
                }
                catch (DslSyntaxError ex)
                {
                    Check(ex.Message == c.message, "parser diag message " + c.name + " (" + ex.Message + " == " + c.message + ")");
                    Check(ex.Diagnostic != null, "parser diag non-null " + c.name);
                    if (ex.Diagnostic != null)
                    {
                        Check(ex.Diagnostic.Code == c.code, "parser diag code " + c.name + " (" + ex.Diagnostic.Code + " == " + c.code + ")");
                        Check(ex.Diagnostic.Stage == "parser", "parser diag stage " + c.name);
                        Check(ex.Diagnostic.Severity == DiagnosticSeverity.Error, "parser diag severity " + c.name);
                        Check(ex.Diagnostic.Location != null && ex.Diagnostic.Location.Line == c.line && ex.Diagnostic.Location.Column == c.column, "parser diag loc " + c.name);
                        Check(ex.Diagnostic.Span == null, "parser diag span null " + c.name);
                    }
                }
                catch (Exception ex)
                {
                    Check(false, "TestStructuredParserDiagnostics: unexpected exception for " + c.name + ": " + ex);
                }

                // Test via DslCompiler.Compile(source)
                try
                {
                    DslCompiler.Compile(c.source, ProbeRegistry());
                    Check(false, "TestStructuredParserDiagnostics compile: expected error for " + c.name);
                }
                catch (DslSyntaxError ex)
                {
                    Check(ex.Message == c.message, "compile parser diag message " + c.name);
                    Check(ex.Diagnostic != null && ex.Diagnostic.Code == c.code, "compile parser diag code " + c.name);
                }
                catch (Exception ex)
                {
                    Check(false, "TestStructuredParserDiagnostics compile: unexpected exception for " + c.name + ": " + ex);
                }
            }

            // Test explicit unavailable caller-token coordinates
            var unlocatedCases = new (object line, object col, string expectedMsg)[]
            {
                (null, null, "Expect '(' at line undefined col undefined"),
                (1, null, "Expect '(' at line 1 col undefined"),
                (0, 1, "Expect '(' at line 0 col 1"),
                (1, double.NaN, "Expect '(' at line 1 col NaN"),
            };

            foreach (var uc in unlocatedCases)
            {
                var tokens = Lexer.Lex("search synth\nrender o0");
                for (int i = 0; i < tokens.Count; i++)
                {
                    if (tokens[i].Type == TokenType.OUTPUT_REF)
                    {
                        tokens[i] = new Token(tokens[i].Type, tokens[i].Lexeme, uc.line, uc.col);
                    }
                }
                try
                {
                    Parser.Parse(tokens);
                    Check(false, "expected parse error for unlocated coordinates: " + uc.expectedMsg);
                }
                catch (DslSyntaxError ex)
                {
                    Check(ex.Message == uc.expectedMsg, "unlocated message: " + ex.Message + " == " + uc.expectedMsg);
                    Check(ex.Diagnostic != null, "unlocated diagnostic non-null");
                    if (ex.Diagnostic != null)
                    {
                        Check(ex.Diagnostic.Code == "P001", "unlocated diag code P001");
                        Check(ex.Diagnostic.Location == null, "unlocated diag location null");
                        Check(ex.Diagnostic.Span == null, "unlocated diag span null");
                    }
                }
            }
        }

        private static void TestStructuredParserDiagnosticsP003Automation()
        {
            var cases = new (string name, string expr, string message)[]
            {
                ("osc unknown param", "osc(type: oscKind.sine, bogus: 1)", "osc() unknown parameter 'bogus' at line 2 col 1. Valid: type, min, max, speed, offset, seed"),
                ("midi keyword-only", "midi(1, 2, 3, 4, 5, 6)", "midi() name, id, cc, nrpn, zone and members are keyword-only at line 2 col 1"),
                ("midi unknown param", "midi(channel: 1, bogus: 2)", "midi() unknown parameter 'bogus' at line 2 col 1. Valid: channel, mode, min, max, sensitivity, name, id, cc, nrpn, zone, members"),
                ("midi excess positional", "midi(1, 2, 3, 4, 5, channel: 6)", "midi() has an excess positional argument at line 2 col 1"),
                ("midi requires channel or zone", "midi()", "midi() requires 'channel' or 'zone' argument at line 2 col 1"),
                ("midi channel and zone mutually exclusive", "midi(channel: 1, zone: 2)", "midi() 'channel' and 'zone' are mutually exclusive at line 2 col 1"),
                ("midi members requires zone", "midi(channel: 1, members: 2)", "midi() 'members' requires 'zone' at line 2 col 1"),
                ("midi id requires name", "midi(channel: 1, id: \"pad\")", "midi() 'id' requires readable 'name' at line 2 col 1"),
                ("midi name requires quoted string", "midi(channel: 1, name: 1)", "midi() 'name' requires a quoted string at line 2 col 1"),
                ("midi name must not be empty", "midi(channel: 1, name: \"\")", "midi() 'name' must not be empty at line 2 col 1"),
                ("midi id requires quoted string", "midi(channel: 1, name: \"pad\", id: 1)", "midi() 'id' requires a quoted string at line 2 col 1"),
                ("midi id must not be empty", "midi(channel: 1, name: \"pad\", id: \"\")", "midi() 'id' must not be empty at line 2 col 1"),
                ("audio keyword-only", "audio(1, 2, 3, 4)", "audio() channel, name and id are keyword-only at line 2 col 1"),
                ("audio unknown param", "audio(band: 1, bogus: 2)", "audio() unknown parameter 'bogus' at line 2 col 1. Valid: band, min, max, channel, name, id"),
                ("audio excess positional", "audio(1, 2, 3, band: 4)", "audio() has an excess positional argument at line 2 col 1"),
                ("audio requires band", "audio()", "audio() requires 'band' argument at line 2 col 1"),
                ("audio id requires name", "audio(band: 1, id: \"mic\")", "audio() 'id' requires readable 'name' at line 2 col 1"),
                ("audio selected device requires channel", "audio(band: 1, name: \"mic\")", "audio() selected device requires both 'name' and 'channel' at line 2 col 1"),
                ("audio name requires quoted string", "audio(band: 1, channel: 1, name: 1)", "audio() 'name' requires a quoted string at line 2 col 1"),
                ("audio name must not be empty", "audio(band: 1, channel: 1, name: \"\")", "audio() 'name' must not be empty at line 2 col 1"),
                ("audio id requires quoted string", "audio(band: 1, channel: 1, name: \"mic\", id: 1)", "audio() 'id' requires a quoted string at line 2 col 1"),
                ("audio id must not be empty", "audio(band: 1, channel: 1, name: \"mic\", id: \"\")", "audio() 'id' must not be empty at line 2 col 1"),
            };

            foreach (var c in cases)
            {
                try
                {
                    string src = "search synth\n" + c.expr;
                    Parser.Parse(Lexer.Lex(src), ProbeRegistry());
                    Check(false, "TestStructuredParserDiagnosticsP003Automation: expected parse error for " + c.name);
                }
                catch (DslSyntaxError ex)
                {
                    Check(ex.Message == c.message, "P003 msg " + c.name + " (" + ex.Message + " == " + c.message + ")");
                    Check(ex.Diagnostic != null, "P003 diag non-null " + c.name);
                    if (ex.Diagnostic != null)
                    {
                        Check(ex.Diagnostic.Code == "P003", "P003 code " + c.name);
                        Check(ex.Diagnostic.Stage == "parser", "P003 stage " + c.name);
                        Check(ex.Diagnostic.Severity == DiagnosticSeverity.Error, "P003 severity " + c.name);
                        Check(ex.Diagnostic.Location != null && ex.Diagnostic.Location.Line == 2 && ex.Diagnostic.Location.Column == 1, "P003 loc " + c.name);
                        Check(ex.Diagnostic.Span == null, "P003 span null " + c.name);
                    }
                }
                catch (Exception ex)
                {
                    Check(false, "TestStructuredParserDiagnosticsP003Automation: unexpected exception for " + c.name + ": " + ex);
                }
            }

            // coordinates with CRLF, tab, and surrogate pairs
            try
            {
                string utfSrc = "search synth\r\n\tlet x = \"😀\"; let y = midi()";
                Parser.Parse(Lexer.Lex(utfSrc), ProbeRegistry());
                Check(false, "expected parse error for midi in utfSrc");
            }
            catch (DslSyntaxError ex)
            {
                Check(ex.Diagnostic != null && ex.Diagnostic.Code == "P003", "P003 utf code");
                Check(ex.Diagnostic != null && ex.Diagnostic.Location != null && ex.Diagnostic.Location.Line == 2 && ex.Diagnostic.Location.Column == 24, "P003 utf loc");
            }
        }

        private static void TestStructuredParserDiagnosticsP004Search()
        {
            string missingMsg = "Missing required 'search' directive. Every program must start with 'search <namespace>, ...' to specify namespace search order.";
            var cases = new (string name, string source, string message, int line, int column)[]
            {
                ("empty program", "", missingMsg, 1, 1),
                ("missing directive after statements", "let x = 1", missingMsg, 1, 10),
                ("duplicate search directive", "search synth\nsearch filter", "Only one search directive is allowed per program at line 2 col 1", 2, 1),
                ("misplaced search directive", "let x = 1\nsearch synth", "'search' directive must appear before other statements at line 2 col 1", 2, 1),
                ("nested search directive", "search synth\nif (true) {\n  search filter\n}", "'search' directive is only allowed at the start of the program at line 3 col 3", 3, 3),
                ("missing first namespace", "search", "Expected namespace identifier after search at line 1 col 7", 1, 7),
                ("missing trailing namespace", "search synth,", "Expected namespace identifier after comma at line 1 col 14", 1, 14),
                ("CRLF offset", "search synth\r\nsearch filter", "Only one search directive is allowed per program at line 2 col 1", 2, 1),
                ("UTF-16 column offset", "search synth\nlet x = \"😀\"; search filter", "'search' directive must appear before other statements at line 2 col 15", 2, 15),
            };

            foreach (var c in cases)
            {
                try
                {
                    Parser.Parse(Lexer.Lex(c.source), ProbeRegistry());
                    Check(false, "TestStructuredParserDiagnosticsP004Search: expected parse error for " + c.name);
                }
                catch (DslSyntaxError ex)
                {
                    Check(ex.Message == c.message, "P004 msg " + c.name + " (" + ex.Message + " == " + c.message + ")");
                    Check(ex.Diagnostic != null, "P004 diag non-null " + c.name);
                    if (ex.Diagnostic != null)
                    {
                        Check(ex.Diagnostic.Code == "P004", "P004 code " + c.name);
                        Check(ex.Diagnostic.Stage == "parser", "P004 stage " + c.name);
                        Check(ex.Diagnostic.Severity == DiagnosticSeverity.Error, "P004 severity " + c.name);
                        Check(ex.Diagnostic.Location != null && ex.Diagnostic.Location.Line == c.line && ex.Diagnostic.Location.Column == c.column, "P004 loc " + c.name);
                        Check(ex.Diagnostic.Span == null, "P004 span null " + c.name);
                    }
                }
                catch (Exception ex)
                {
                    Check(false, "TestStructuredParserDiagnosticsP004Search: unexpected exception for " + c.name + ": " + ex);
                }
            }

            // Invalid namespace test
            try
            {
                Parser.Parse(Lexer.Lex("search nonexistentNamespace\nrender(o0)\n"), ProbeRegistry());
                Check(false, "TestStructuredParserDiagnosticsP004Search: expected invalid namespace error");
            }
            catch (DslSyntaxError ex)
            {
                Check(ex.Diagnostic != null && ex.Diagnostic.Code == "P004", "P004 invalid namespace code");
                Check(ex.Diagnostic != null && ex.Diagnostic.Location != null && ex.Diagnostic.Location.Line == 1 && ex.Diagnostic.Location.Column == 8, "P004 invalid namespace location");
                Check(ex.Message.StartsWith("Invalid namespace 'nonexistentNamespace' at line 1 col 8"), "P004 invalid namespace message start");
            }

            // Unavailable caller-token coordinates test for P003 and P004
            var unlocatedCases = new (object line, object col, string lineStr, string colStr)[]
            {
                (null, null, "undefined", "undefined"),
                (1, null, "1", "undefined"),
                (0, 1, "0", "1"),
                (1, double.NaN, "1", "NaN"),
            };

            foreach (var uc in unlocatedCases)
            {
                var tokens = new List<Token>
                {
                    new Token(TokenType.SEARCH, "search", 1, 1),
                    new Token(TokenType.IDENT, "synth", 1, 8),
                    new Token(TokenType.IDENT, "midi", uc.line, uc.col),
                    new Token(TokenType.LPAREN, "(", 2, 5),
                    new Token(TokenType.RPAREN, ")", 2, 6),
                    new Token(TokenType.EOF, "", 2, 7)
                };
                try
                {
                    Parser.Parse(tokens, ProbeRegistry());
                    Check(false, "expected parse error for unlocated midi coordinates");
                }
                catch (DslSyntaxError ex)
                {
                    string expectedMsg = $"midi() requires 'channel' or 'zone' argument at line {uc.lineStr} col {uc.colStr}";
                    Check(ex.Message == expectedMsg, "unlocated P003 message: " + ex.Message + " == " + expectedMsg);
                    Check(ex.Diagnostic != null, "unlocated P003 diagnostic non-null");
                    if (ex.Diagnostic != null)
                    {
                        Check(ex.Diagnostic.Code == "P003", "unlocated diag code P003");
                        Check(ex.Diagnostic.Location == null, "unlocated diag location null");
                        Check(ex.Diagnostic.Span == null, "unlocated diag span null");
                    }
                }

                var eofTokens = new List<Token>
                {
                    new Token(TokenType.EOF, "", uc.line, uc.col)
                };
                try
                {
                    Parser.Parse(eofTokens, ProbeRegistry());
                    Check(false, "expected parse error for unlocated missing search");
                }
                catch (DslSyntaxError ex)
                {
                    Check(ex.Message == missingMsg, "unlocated P004 missing search msg: " + ex.Message);
                    Check(ex.Diagnostic != null, "unlocated P004 diagnostic non-null");
                    if (ex.Diagnostic != null)
                    {
                        Check(ex.Diagnostic.Code == "P004", "unlocated diag code P004");
                        Check(ex.Diagnostic.Location == null, "unlocated diag location null");
                        Check(ex.Diagnostic.Span == null, "unlocated diag span null");
                    }
                }
            }
        }

        private static void TestStructuredParserDiagnosticsP005Output()
        {
            var cases = new (string name, string source, string message, int line, int column)[]
            {
                ("render string target", "search synth\nrender(\"o0\")", "Expected output reference in render()", 2, 8),
                ("render numeric target", "search synth\nrender(1)", "Expected output reference in render()", 2, 8),
                ("render EOF target", "search synth\nrender(", "Expected output reference in render()", 2, 8),
                ("expression context write", "search synth\nlet x = diagProbe().write(o0)", "'.write()' is only allowed in statement context at line 2 col 21", 2, 21),
                ("expression context write3d", "search synth\nlet x = diagProbe().write3d(vol0, geo0)", "'.write()' is only allowed in statement context at line 2 col 21", 2, 21),
                ("render call write argument", "search synth\nrender(diagProbe().write(o0))", "Expected output reference in render()", 2, 8),
                ("write numeric surface", "search synth\ndiagProbe().write(1)", "write() requires an explicit surface reference (e.g., o0, o1, xyz0, vel0, rgba0, mesh0, none) at line 2 col 19", 2, 19),
                ("write empty surface", "search synth\ndiagProbe().write()", "write() requires an explicit surface reference (e.g., o0, o1, xyz0, vel0, rgba0, mesh0, none) at line 2 col 19", 2, 19),
                ("write unknown identifier", "search synth\ndiagProbe().write(bogus)", "write() requires an explicit surface reference (e.g., o0, o1, xyz0, vel0, rgba0, mesh0, none) at line 2 col 19", 2, 19),
                ("write at EOF", "search synth\ndiagProbe().write(", "write() requires an explicit surface reference (e.g., o0, o1, xyz0, vel0, rgba0, mesh0, none) at line 2 col 19", 2, 19),
                ("write3d numeric texture", "search synth\ndiagProbe().write3d(1, geo0)", "Expected tex3d reference in write3d() at line 2 col 21", 2, 21),
                ("write3d empty texture", "search synth\ndiagProbe().write3d()", "Expected tex3d reference in write3d() at line 2 col 21", 2, 21),
                ("write3d texture at EOF", "search synth\ndiagProbe().write3d(", "Expected tex3d reference in write3d() at line 2 col 21", 2, 21),
                ("write3d numeric geometry", "search synth\ndiagProbe().write3d(vol0, 1)", "Expected geo reference in write3d() at line 2 col 27", 2, 27),
                ("write3d geometry at EOF", "search synth\ndiagProbe().write3d(vol0,", "Expected geo reference in write3d() at line 2 col 26", 2, 26),
                ("CRLF and tab render target", "// 😀\r\nsearch synth\r\n\trender(\"😀\")", "Expected output reference in render()", 3, 9),
                ("UTF-16 render target column", "search synth\nlet x = \"😀\"; render(none)", "Expected output reference in render()", 2, 22),
            };

            foreach (var c in cases)
            {
                try
                {
                    Parser.Parse(Lexer.Lex(c.source), ProbeRegistry());
                    Check(false, "TestStructuredParserDiagnosticsP005Output: expected parse error for " + c.name);
                }
                catch (DslSyntaxError ex)
                {
                    Check(ex.Message == c.message, "P005 msg " + c.name + " (" + ex.Message + " == " + c.message + ")");
                    Check(ex.Diagnostic != null, "P005 diag non-null " + c.name);
                    if (ex.Diagnostic != null)
                    {
                        Check(ex.Diagnostic.Code == "P005", "P005 code " + c.name + " (" + ex.Diagnostic.Code + " == P005)");
                        Check(ex.Diagnostic.Stage == "parser", "P005 stage " + c.name);
                        Check(ex.Diagnostic.Severity == DiagnosticSeverity.Error, "P005 severity " + c.name);
                        Check(ex.Diagnostic.Location != null && ex.Diagnostic.Location.Line == c.line && ex.Diagnostic.Location.Column == c.column, "P005 loc " + c.name + $" ({ex.Diagnostic.Location?.Line},{ex.Diagnostic.Location?.Column} == {c.line},{c.column})");
                        Check(ex.Diagnostic.Span == null, "P005 span null " + c.name);
                    }
                }
                catch (Exception ex)
                {
                    Check(false, "TestStructuredParserDiagnosticsP005Output: unexpected exception for " + c.name + ": " + ex);
                }
            }

            // Unavailable caller-token coordinates test for P005
            var unlocatedCases = new (object line, object col, string lineStr, string colStr)[]
            {
                (null, null, "undefined", "undefined"),
                (1, null, "1", "undefined"),
                (0, 1, "0", "1"),
                (1, double.NaN, "1", "NaN"),
            };

            var outputFailures = new (string name, string src)[]
            {
                ("render string target", "search synth\nrender(\"o0\")"),
                ("render numeric target", "search synth\nrender(1)"),
                ("expression context write", "search synth\nlet x = diagProbe().write(o0)"),
                ("expression context write3d", "search synth\nlet x = diagProbe().write3d(vol0, geo0)"),
                ("write numeric surface", "search synth\ndiagProbe().write(1)"),
                ("write at EOF", "search synth\ndiagProbe().write("),
                ("invalid write3d texture", "search synth\ndiagProbe().write3d(1, geo0)"),
                ("write3d texture at EOF", "search synth\ndiagProbe().write3d("),
                ("invalid write3d geometry", "search synth\ndiagProbe().write3d(vol0, 1)"),
                ("write3d geometry at EOF", "search synth\ndiagProbe().write3d(vol0,"),
                ("CRLF and tab render target", "// 😀\r\nsearch synth\r\n\trender(\"😀\")"),
                ("UTF-16 render target column", "search synth\nlet x = \"😀\"; render(none)"),
            };

            foreach (var of in outputFailures)
            {
                foreach (var uc in unlocatedCases)
                {
                    var tokens = new List<Token>();
                    foreach (var t in Lexer.Lex(of.src))
                    {
                        tokens.Add(new Token(t.Type, t.Lexeme, uc.line, uc.col));
                    }
                    try
                    {
                        Parser.Parse(tokens, ProbeRegistry());
                        Check(false, "expected parse error for unlocated " + of.name);
                    }
                    catch (DslSyntaxError ex)
                    {
                        Check(ex.Diagnostic != null, "unlocated P005 diag non-null " + of.name);
                        if (ex.Diagnostic != null)
                        {
                            Check(ex.Diagnostic.Code == "P005", "unlocated diag code P005 for " + of.name);
                            Check(ex.Diagnostic.Location == null, "unlocated diag location null for " + of.name);
                            Check(ex.Diagnostic.Span == null, "unlocated diag span null for " + of.name);
                        }
                    }
                }
            }

            // Valid output operations AST check
            string[] validSurfaces = { "o0", "xyz0", "vel0", "rgba0", "mesh0", "none" };
            foreach (var s in validSurfaces)
            {
                try
                {
                    var ast = Parser.Parse(Lexer.Lex($"search synth\ndiagProbe().write({s})"), ProbeRegistry());
                    Check(ast != null && ast.Plans.Count > 0, "valid write ast for " + s);
                }
                catch (Exception ex)
                {
                    Check(false, "valid write failed for " + s + ": " + ex.Message);
                }
            }

            var validWrite3d = new (string tex, string geo)[]
            {
                ("vol0", "geo0"),
                ("o0", "o1"),
                ("volume", "geometry"),
            };
            foreach (var w in validWrite3d)
            {
                try
                {
                    var ast = Parser.Parse(Lexer.Lex($"search synth\ndiagProbe().write3d({w.tex}, {w.geo})"), ProbeRegistry());
                    Check(ast != null && ast.Plans.Count > 0, $"valid write3d ast for {w.tex}, {w.geo}");
                }
                catch (Exception ex)
                {
                    Check(false, $"valid write3d failed for {w.tex}, {w.geo}: {ex.Message}");
                }
            }
        }

        private static void TestStructuredParserDiagnosticsP006Subchain()
        {
            var cases = new (string name, string source, string message, int line, int column)[]
            {
                ("non-string argument", "search synth\nread(o0).subchain(name: 1) { .diagProbe() }", "Expected string value for subchain name at line 2 col 25", 2, 25),
                ("argument at EOF", "search synth\nread(o0).subchain(name:", "Expected string value for subchain name at line 2 col 24", 2, 24),
                ("missing body dot", "search synth\nread(o0).subchain() { diagProbe() }", "Expected '.' before chain element in subchain body at line 2 col 23", 2, 23),
                ("body at EOF", "search synth\nread(o0).subchain() {", "Expected '.' before chain element in subchain body at line 2 col 22", 2, 22),
                ("empty body", "search synth\nread(o0).subchain() {}", "Subchain body cannot be empty at line 2 col 10", 2, 10),
                ("comment-only body", "search synth\nread(o0).subchain() { /* empty */ }", "Subchain body cannot be empty at line 2 col 10", 2, 10),
                ("CRLF tab and UTF-16 argument", "// 😀\r\nsearch synth\r\n\tread(o0).subchain(name: \"😀\", id: 1) { .diagProbe() }", "Expected string value for subchain id at line 3 col 36", 3, 36),
                ("missing dot after comment", "search synth\nread(o0).subchain() { /* 😀 */ missing() }", "Expected '.' before chain element in subchain body at line 2 col 32", 2, 32),
                ("unclosed nonempty body", "search synth\nread(o0).subchain() { .diagProbe()", "Expected '.' before chain element in subchain body at line 2 col 35", 2, 35),
            };

            foreach (var c in cases)
            {
                try
                {
                    Parser.Parse(Lexer.Lex(c.source), ProbeRegistry());
                    Check(false, "TestStructuredParserDiagnosticsP006Subchain: expected parse error for " + c.name);
                }
                catch (DslSyntaxError ex)
                {
                    Check(ex.Message == c.message, "P006 msg " + c.name + " (" + ex.Message + " == " + c.message + ")");
                    Check(ex.Diagnostic != null, "P006 diag non-null " + c.name);
                    if (ex.Diagnostic != null)
                    {
                        Check(ex.Diagnostic.Code == "P006", "P006 code " + c.name + " (" + ex.Diagnostic.Code + " == P006)");
                        Check(ex.Diagnostic.Stage == "parser", "P006 stage " + c.name);
                        Check(ex.Diagnostic.Severity == DiagnosticSeverity.Error, "P006 severity " + c.name);
                        Check(ex.Diagnostic.Location != null && ex.Diagnostic.Location.Line == c.line && ex.Diagnostic.Location.Column == c.column, "P006 loc " + c.name + $" ({ex.Diagnostic.Location?.Line},{ex.Diagnostic.Location?.Column} == {c.line},{c.column})");
                        Check(ex.Diagnostic.Span == null, "P006 span null " + c.name);
                    }
                }
                catch (Exception ex)
                {
                    Check(false, "TestStructuredParserDiagnosticsP006Subchain: unexpected exception for " + c.name + ": " + ex);
                }
            }

            // Unavailable caller-token coordinates test for P006
            var unlocatedCases = new (object line, object col, string lineStr, string colStr)[]
            {
                (null, null, "undefined", "undefined"),
                (1, null, "1", "undefined"),
                (0, 1, "0", "1"),
                (1, double.NaN, "1", "NaN"),
            };

            foreach (var c in cases)
            {
                foreach (var uc in unlocatedCases)
                {
                    var tokens = new List<Token>();
                    foreach (var t in Lexer.Lex(c.source))
                    {
                        tokens.Add(new Token(t.Type, t.Lexeme, uc.line, uc.col));
                    }
                    try
                    {
                        Parser.Parse(tokens, ProbeRegistry());
                        Check(false, "expected parse error for unlocated " + c.name);
                    }
                    catch (DslSyntaxError ex)
                    {
                        Check(ex.Diagnostic != null, "unlocated P006 diag non-null " + c.name);
                        if (ex.Diagnostic != null)
                        {
                            Check(ex.Diagnostic.Code == "P006", "unlocated diag code P006 for " + c.name);
                            Check(ex.Diagnostic.Location == null, "unlocated diag location null for " + c.name);
                            Check(ex.Diagnostic.Span == null, "unlocated diag span null for " + c.name);
                        }
                    }
                }
            }

            // Shared expectation diagnostic precedence
            var precedenceCases = new (string source, string code, string message)[]
            {
                ("search synth\nread(o0).subchain(1) {}", "P002", "Expect ')' after subchain arguments at line 2 col 19"),
                ("search synth\nread(o0).subchain() { . }", "P001", "Expected identifier at line 2 col 25"),
            };

            foreach (var pc in precedenceCases)
            {
                try
                {
                    Parser.Parse(Lexer.Lex(pc.source), ProbeRegistry());
                    Check(false, "expected error for precedence " + pc.code);
                }
                catch (DslSyntaxError ex)
                {
                    Check(ex.Message == pc.message, "precedence msg " + pc.code + " (" + ex.Message + " == " + pc.message + ")");
                    Check(ex.Diagnostic != null && ex.Diagnostic.Code == pc.code, "precedence code " + pc.code);
                }
            }

            // Valid subchains AST and validator steps
            var validCases = new (string args, string name, string id, int diagCount)[]
            {
                ("", null, null, 0),
                ("\"positional\"", "positional", null, 0),
                ("name: \"named\", id: \"s\"", "named", "s", 0),
                ("foo: \"x\" name: \"a\" name: \"b\" id: \"s\"", "b", "s", 5),
            };

            var reg = ProbeRegistry();
            foreach (var vc in validCases)
            {
                string source = $"search synth\nread(o0).subchain({vc.args}) {{ .diagFilter() }}.write(o1)";
                var tokens = Lexer.Lex(source);
                var ast = Parser.Parse(tokens, reg);
                Check(ast != null && ast.Plans.Count > 0, "valid subchain ast not null for " + vc.args);
                var chainStmt = ast.Plans[0] as ChainStatementNode;
                Check(chainStmt != null && chainStmt.Chain.Count > 1, "valid subchain chain count for " + vc.args);
                var subNode = chainStmt?.Chain[1] as SubchainNode;
                Check(subNode != null, "subNode is SubchainNode for " + vc.args);
                if (subNode != null)
                {
                    Check(subNode.Name == vc.name, $"subchain name '{subNode.Name}' == '{vc.name}'");
                    Check(subNode.Id == vc.id, $"subchain id '{subNode.Id}' == '{vc.id}'");
                    Check(subNode.Body.Count == 1, "subchain body count == 1");
                    var call = subNode.Body[0] as CallNode;
                    Check(call != null && call.Name == "diagFilter", "subchain body call is diagFilter");
                    Check(subNode.LocLine == 2 && subNode.LocCol == 10, $"subchain loc ({subNode.LocLine},{subNode.LocCol}) == (2,10)");
                }

                var validated = Validator.Validate(ast, reg);
                Check(validated.Diagnostics.Count == vc.diagCount, "valid subchain diagnostics count for " + vc.args);
                Check(validated.Plans.Count == 1, "valid subchain 1 plan for " + vc.args);
                var steps = validated.Plans[0].Chain;
                Check(steps.Count == 5, "valid subchain 5 steps for " + vc.args);
                if (steps.Count == 5)
                {
                    Check(steps[0].Op == "_read" && steps[0].Builtin && steps[0].Temp == 0, "step 0 _read");
                    Check(steps[1].Op == "_subchain_begin" && steps[1].Builtin && steps[1].Temp == 1 && steps[1].From == 0, "step 1 _subchain_begin");
                    Check(steps[1].Args.Get("name")?.String == vc.name, $"step 1 name == {vc.name}");
                    Check(steps[1].Args.Get("id")?.String == vc.id, $"step 1 id == {vc.id}");
                    Check(steps[2].Op == "synth.diagFilter" && !steps[2].Builtin && steps[2].Temp == 2 && steps[2].From == 1, "step 2 synth.diagFilter");
                    Check(steps[3].Op == "_subchain_end" && steps[3].Builtin && steps[3].Temp == 3 && steps[3].From == 2, "step 3 _subchain_end");
                    Check(steps[3].Args.Get("name")?.String == vc.name, $"step 3 name == {vc.name}");
                    Check(steps[3].Args.Get("id")?.String == vc.id, $"step 3 id == {vc.id}");
                    Check(steps[4].Op == "_write" && steps[4].Builtin && steps[4].Temp == 4 && steps[4].From == 3, "step 4 _write");
                }
                Check(validated.Render == null, "valid subchain render null for " + vc.args);
            }
        }

        private static void TestSubchainArgumentDiagnosticsGAP027()
        {
            var reg = ProbeRegistry();

            // 1. P008: Unknown subchain key
            {
                string source = "search synth\nread(o0).subchain(nme: \"typo\", name: \"ok\") { .diagFilter() }.write(o1)";
                var ast = Parser.Parse(Lexer.Lex(source), reg);
                var sub = (ast.Plans[0] as ChainStatementNode)?.Chain[1] as SubchainNode;
                Check(sub != null && sub.Name == "ok" && sub.Id == null, "P008: discarded nme from AST");
                var validated = Validator.Validate(ast, reg);
                var p008 = validated.Diagnostics.FindAll(d => d.Code == "P008");
                Check(p008.Count == 1, "P008 count == 1");
                if (p008.Count == 1)
                {
                    Check(p008[0].Severity == DiagnosticSeverity.Warning, "P008 severity warning");
                    Check(p008[0].Message.Contains("Unknown subchain argument 'nme'"), "P008 message contains nme");
                    Check(p008[0].Location != null && p008[0].Location.Line == 2 && p008[0].Location.Column == 19, "P008 location (2,19)");
                }
            }

            // 2. P009: Duplicate subchain key
            {
                string source = "search synth\nread(o0).subchain(name: \"first\", name: \"second\") { .diagFilter() }.write(o1)";
                var ast = Parser.Parse(Lexer.Lex(source), reg);
                var sub = (ast.Plans[0] as ChainStatementNode)?.Chain[1] as SubchainNode;
                Check(sub != null && sub.Name == "second", "P009: last value second wins");
                var validated = Validator.Validate(ast, reg);
                var p009 = validated.Diagnostics.FindAll(d => d.Code == "P009");
                Check(p009.Count == 1, "P009 count == 1");
                if (p009.Count == 1)
                {
                    Check(p009[0].Severity == DiagnosticSeverity.Warning, "P009 severity warning");
                    Check(p009[0].Message.Contains("Duplicate subchain argument 'name'"), "P009 message contains name");
                    Check(p009[0].Location != null && p009[0].Location.Line == 2 && p009[0].Location.Column == 34, $"P009 location ({p009[0].Location?.Line},{p009[0].Location?.Column} == 2,34)");
                }
            }

            // 3. P010: Missing comma separator
            {
                string source = "search synth\nread(o0).subchain(name: \"a\" id: \"b\") { .diagFilter() }.write(o1)";
                var ast = Parser.Parse(Lexer.Lex(source), reg);
                var sub = (ast.Plans[0] as ChainStatementNode)?.Chain[1] as SubchainNode;
                Check(sub != null && sub.Name == "a" && sub.Id == "b", "P010: AST parsed both name and id");
                var validated = Validator.Validate(ast, reg);
                var p010 = validated.Diagnostics.FindAll(d => d.Code == "P010");
                Check(p010.Count == 1, "P010 count == 1");
                if (p010.Count == 1)
                {
                    Check(p010[0].Severity == DiagnosticSeverity.Warning, "P010 severity warning");
                    Check(p010[0].Message.Contains("Missing ',' between subchain arguments"), "P010 message text");
                    Check(p010[0].Location != null && p010[0].Location.Line == 2 && p010[0].Location.Column == 29, "P010 location (2,29)");
                }
            }

            // 4. Co-occurring violations in source order
            {
                string source = "search synth\nread(o0).subchain(nme: \"x\", name: \"a\" name: \"b\") { .diagFilter() }.write(o1)";
                var ast = Parser.Parse(Lexer.Lex(source), reg);
                var validated = Validator.Validate(ast, reg);
                Check(validated.Diagnostics.Count == 3, "co-occurring diagnostics count == 3");
                if (validated.Diagnostics.Count == 3)
                {
                    Check(validated.Diagnostics[0].Code == "P008", "diag[0] is P008");
                    Check(validated.Diagnostics[1].Code == "P010", "diag[1] is P010");
                    Check(validated.Diagnostics[2].Code == "P009", "diag[2] is P009");
                }
            }

            // 5. Strict mode throws DslSyntaxError with Error severity
            var strictCases = new (string source, string code)[]
            {
                ("search synth\nread(o0).subchain(nme: \"x\") { .diagFilter() }.write(o1)", "P008"),
                ("search synth\nread(o0).subchain(name: \"a\", name: \"b\") { .diagFilter() }.write(o1)", "P009"),
                ("search synth\nread(o0).subchain(name: \"a\" id: \"b\") { .diagFilter() }.write(o1)", "P010"),
            };
            var strictOpt = new ParserOptions { SubchainArguments = "strict" };
            foreach (var sc in strictCases)
            {
                try
                {
                    Parser.Parse(Lexer.Lex(sc.source), reg, strictOpt);
                    Check(false, "strict mode expected exception for " + sc.code);
                }
                catch (DslSyntaxError ex)
                {
                    Check(ex.Diagnostic != null && ex.Diagnostic.Code == sc.code, "strict mode code " + sc.code);
                    Check(ex.Diagnostic != null && ex.Diagnostic.Severity == DiagnosticSeverity.Error, "strict mode severity Error for " + sc.code);
                }
            }

            // 6. DslCompiler integration: options forwarding
            {
                string dsl = "search synth\nread(o0).subchain(nme: \"x\") { .diagFilter() }.write(o1)\nrender(o1)\n";
                // Default mode succeeds
                var graph = DslCompiler.Compile(dsl, reg);
                Check(graph != null, "DslCompiler default mode succeeds with P008 warning");

                // Strict mode throws
                try
                {
                    DslCompiler.Compile(dsl, reg, strictOpt);
                    Check(false, "DslCompiler strict mode expected error");
                }
                catch (DslSyntaxError ex)
                {
                    Check(ex.Diagnostic != null && ex.Diagnostic.Code == "P008", "DslCompiler strict throws P008");
                }
            }

            // 7. Preserves unavailable caller-token coordinates without throwing
            {
                var unlocatedCases = new (object line, object col, string lineStr, string colStr)[]
                {
                    (null, null, "undefined", "undefined"),
                    (1, null, "1", "undefined"),
                    (0, 1, "0", "1"),
                    (1, double.NaN, "1", "NaN"),
                };
                string dsl = "search synth\nread(o0).subchain(nme: \"x\") { .diagFilter() }.write(o1)";
                foreach (var uc in unlocatedCases)
                {
                    var tokens = new List<Token>();
                    foreach (var t in Lexer.Lex(dsl))
                        tokens.Add(new Token(t.Type, t.Lexeme, uc.line, uc.col));

                    var ast = Parser.Parse(tokens, reg);
                    var validated = Validator.Validate(ast, reg);
                    var p008 = validated.Diagnostics.Find(d => d.Code == "P008");
                    Check(p008 != null, "P008 reported for unlocated token");
                    if (p008 != null)
                    {
                        Check(p008.Message.Contains($"line {uc.lineStr} col {uc.colStr}"), $"P008 message coordinates {uc.lineStr},{uc.colStr}");
                    }
                }
            }
        }

        private static void TestStructuredParserDiagnosticsP007CallForm()
        {
            var cases = new (string name, string source, string message, int line, int column)[]
            {
                ("from named arguments", "search synth\nlet x = from(a: 1, b: 2)", "'from' does not support named arguments at line 2 col 9", 2, 9),
                ("from missing second argument", "search synth\nlet x = from(synth)", "'from' requires exactly two arguments (namespace, call) at line 2 col 9", 2, 9),
                ("from namespace not an identifier", "search synth\nlet x = from(1, diagProbe())", "'from' namespace argument must be an identifier at line 2 col 9", 2, 9),
                ("from second argument not a call", "search synth\nlet x = from(synth, 1)", "'from' second argument must be a call expression at line 2 col 9", 2, 9),
                ("inline namespace", "search synth\nnd.noise()", "Inline namespace syntax 'nd.noise()' is not allowed. Use 'search nd' at the start of the program instead, at line 2 col 1", 2, 1),
                ("positional then keyword", "search synth\ndiagProbe(1, x: 2)", "Cannot mix positional and keyword arguments at line 2 col 14", 2, 14),
                ("keyword then positional", "search synth\ndiagProbe(x: 1, 2)", "Cannot mix positional and keyword arguments at line 2 col 17", 2, 17),
                ("CRLF tab and UTF-16", "// 😀\r\nsearch synth\r\n\tdiagProbe(1, x: 2)", "Cannot mix positional and keyword arguments at line 3 col 15", 3, 15),
                ("UTF-16 inline namespace column", "search synth\nlet x = \"😀\"; nd.noise()", "Inline namespace syntax 'nd.noise()' is not allowed. Use 'search nd' at the start of the program instead, at line 2 col 15", 2, 15),
            };

            foreach (var c in cases)
            {
                try
                {
                    Parser.Parse(Lexer.Lex(c.source), ProbeRegistry());
                    Check(false, "TestStructuredParserDiagnosticsP007CallForm: expected parse error for " + c.name);
                }
                catch (DslSyntaxError ex)
                {
                    Check(ex.Message == c.message, "P007 msg " + c.name + " (" + ex.Message + " == " + c.message + ")");
                    Check(ex.Diagnostic != null, "P007 diag non-null " + c.name);
                    if (ex.Diagnostic != null)
                    {
                        Check(ex.Diagnostic.Code == "P007", "P007 code " + c.name + " (" + ex.Diagnostic.Code + " == P007)");
                        Check(ex.Diagnostic.Stage == "parser", "P007 stage " + c.name);
                        Check(ex.Diagnostic.Severity == DiagnosticSeverity.Error, "P007 severity " + c.name);
                        Check(ex.Diagnostic.Location != null && ex.Diagnostic.Location.Line == c.line && ex.Diagnostic.Location.Column == c.column, "P007 loc " + c.name + $" ({ex.Diagnostic.Location?.Line},{ex.Diagnostic.Location?.Column} == {c.line},{c.column})");
                        Check(ex.Diagnostic.Span == null, "P007 span null " + c.name);
                    }
                }
                catch (Exception ex)
                {
                    Check(false, "TestStructuredParserDiagnosticsP007CallForm: unexpected exception for " + c.name + ": " + ex);
                }
            }

            // Unavailable caller-token coordinates test for P007
            var unlocatedCases = new (object line, object col)[]
            {
                (null, null),
                (1, null),
                (0, 1),
                (1, double.NaN),
            };

            foreach (var c in cases)
            {
                foreach (var uc in unlocatedCases)
                {
                    var tokens = new List<Token>();
                    foreach (var t in Lexer.Lex(c.source))
                    {
                        tokens.Add(new Token(t.Type, t.Lexeme, uc.line, uc.col));
                    }
                    try
                    {
                        Parser.Parse(tokens, ProbeRegistry());
                        Check(false, "expected parse error for unlocated P007 " + c.name);
                    }
                    catch (DslSyntaxError ex)
                    {
                        Check(ex.Diagnostic != null, "unlocated P007 diag non-null " + c.name);
                        if (ex.Diagnostic != null)
                        {
                            Check(ex.Diagnostic.Code == "P007", "unlocated diag code P007 for " + c.name);
                            Check(ex.Diagnostic.Location == null, "unlocated diag location null for " + c.name);
                            Check(ex.Diagnostic.Span == null, "unlocated diag span null for " + c.name);
                        }
                    }
                }
            }
        }

        private static void TestStructuredParserDiagnosticsP001RemainingExpectations()
        {
            var cases = new (string name, string source, string message, int line, int column)[]
            {
                ("expected expression in assignment", "search synth\nlet x = ;", "Expected expression after '=' at line 2 col 9", 2, 9),
                ("expected expression in keyword argument", "search synth\ndiagProbe(a: )", "Expected expression after '=' at line 2 col 14", 2, 14),
                ("expected closing bracket", "search synth\nlet x = [1 2]", "Expected ']' at line 2 col 12", 2, 12),
                ("expected identifier after dot", "search synth\nlet x = foo.+", "Expected identifier after '.' at line 2 col 13", 2, 13),
                ("unexpected primary token", "search synth\ndiagProbe(; 1)", "Unexpected token SEMICOLON at line 2 col 11", 2, 11),
                ("UTF-16 column", "search synth\nlet x = \"😀\"; let y = [1 2]", "Expected ']' at line 2 col 26", 2, 26),
            };

            foreach (var c in cases)
            {
                try
                {
                    Parser.Parse(Lexer.Lex(c.source), ProbeRegistry());
                    Check(false, "TestStructuredParserDiagnosticsP001RemainingExpectations: expected parse error for " + c.name);
                }
                catch (DslSyntaxError ex)
                {
                    Check(ex.Message == c.message, "P001 msg " + c.name + " (" + ex.Message + " == " + c.message + ")");
                    Check(ex.Diagnostic != null, "P001 diag non-null " + c.name);
                    if (ex.Diagnostic != null)
                    {
                        Check(ex.Diagnostic.Code == "P001", "diag code " + c.name + " (" + ex.Diagnostic.Code + " == P001)");
                        Check(ex.Diagnostic.Stage == "parser", "diag stage " + c.name);
                        Check(ex.Diagnostic.Severity == DiagnosticSeverity.Error, "diag severity " + c.name);
                        Check(ex.Diagnostic.Location != null && ex.Diagnostic.Location.Line == c.line && ex.Diagnostic.Location.Column == c.column, "diag loc " + c.name + $" ({ex.Diagnostic.Location?.Line},{ex.Diagnostic.Location?.Column} == {c.line},{c.column})");
                        Check(ex.Diagnostic.Span == null, "diag span null " + c.name);
                    }
                }
                catch (Exception ex)
                {
                    Check(false, "TestStructuredParserDiagnosticsP001RemainingExpectations: unexpected exception for " + c.name + ": " + ex);
                }
            }

            // Unavailable caller-token coordinates test for P001 cases
            var unlocatedCases = new (object line, object col)[]
            {
                (null, null),
                (1, null),
                (0, 1),
                (1, double.NaN),
            };

            foreach (var c in cases)
            {
                foreach (var uc in unlocatedCases)
                {
                    var tokens = new List<Token>();
                    foreach (var t in Lexer.Lex(c.source))
                    {
                        tokens.Add(new Token(t.Type, t.Lexeme, uc.line, uc.col));
                    }
                    try
                    {
                        Parser.Parse(tokens, ProbeRegistry());
                        Check(false, "expected parse error for unlocated " + c.name);
                    }
                    catch (DslSyntaxError ex)
                    {
                        Check(ex.Diagnostic != null, "unlocated diag non-null " + c.name);
                        if (ex.Diagnostic != null)
                        {
                            Check(ex.Diagnostic.Code == "P001", "unlocated diag code for " + c.name);
                            Check(ex.Diagnostic.Location == null, "unlocated diag location null for " + c.name);
                            Check(ex.Diagnostic.Span == null, "unlocated diag span null for " + c.name);
                        }
                    }
                }
            }
        }

        private static void TestNumberCoercionDiagnostics()
        {
            var unlocatedSources = new string[]
            {
                "search synth\nlet x = 1 + o0",
                "search synth\nlet x = diagProbe() + 1"
            };

            foreach (var src in unlocatedSources)
            {
                try
                {
                    Parser.Parse(Lexer.Lex(src), ProbeRegistry());
                    Check(false, "expected number coercion error for unlocated: " + src);
                }
                catch (DslSyntaxError ex)
                {
                    Check(ex.Message == "Expected number", "number coercion msg (" + ex.Message + " == Expected number)");
                    Check(ex.Diagnostic != null, "number coercion diag non-null");
                    if (ex.Diagnostic != null)
                    {
                        Check(ex.Diagnostic.Code == "P001", "number coercion diag code P001");
                        Check(ex.Diagnostic.Stage == "parser", "number coercion diag stage parser");
                        Check(ex.Diagnostic.Severity == DiagnosticSeverity.Error, "number coercion diag severity error");
                        Check(ex.Diagnostic.Location == null, "number coercion diag location null");
                        Check(ex.Diagnostic.Span == null, "number coercion diag span null");
                    }
                }
            }

            string locatedSource = "search synth\nlet x = 1 + [1, 2]";
            try
            {
                Parser.Parse(Lexer.Lex(locatedSource), ProbeRegistry());
                Check(false, "expected number coercion error for located: " + locatedSource);
            }
            catch (DslSyntaxError ex)
            {
                Check(ex.Message == "Expected number", "located number coercion msg");
                Check(ex.Diagnostic != null, "located number coercion diag non-null");
                if (ex.Diagnostic != null)
                {
                    Check(ex.Diagnostic.Code == "P001", "located number coercion code P001");
                    Check(ex.Diagnostic.Stage == "parser", "located number coercion stage parser");
                    Check(ex.Diagnostic.Severity == DiagnosticSeverity.Error, "located number coercion severity error");
                    Check(ex.Diagnostic.Location != null && ex.Diagnostic.Location.Line == 2 && ex.Diagnostic.Location.Column == 13,
                        $"located number coercion loc ({ex.Diagnostic.Location?.Line},{ex.Diagnostic.Location?.Column} == 2,13)");
                    Check(ex.Diagnostic.Span == null, "located number coercion span null");
                }
            }
        }

        private static void TestValidCallForms()
        {
            var ast = Parser.Parse(Lexer.Lex("search synth\nlet x = from(synth, diagProbe())"), ProbeRegistry());
            Check(ast != null && ast.Vars.Count == 1, "valid from ast non-null");
            var call = ast.Vars[0].Expr as CallNode;
            Check(call != null, "valid from expr is CallNode");
            if (call != null)
            {
                Check(call.Name == "diagProbe", "valid from call name diagProbe");
                Check(call.Namespace != null, "valid from namespace non-null");
                if (call.Namespace != null)
                {
                    Check(call.Namespace.Name == "synth", "valid from namespace name synth");
                    Check(call.Namespace.FromOverride, "valid from fromOverride is true");
                }
            }

            var mixedAst = Parser.Parse(Lexer.Lex("search synth\nlet a = midi(1, channel: 2)"), ProbeRegistry());
            Check(mixedAst != null && mixedAst.Vars.Count == 1, "valid mixed midi ast non-null");
            var midi = mixedAst.Vars[0].Expr as MidiNode;
            Check(midi != null, "valid mixed midi is MidiNode");
            if (midi != null)
            {
                var chanNum = midi.Channel as NumberNode;
                Check(chanNum != null && chanNum.Value == 2.0, "valid mixed midi channel is 2");
            }
        }

        private static void TestRenderLandscape3dFilteringDefines()
        {
            try
            {
                string effectsDir = Path.Combine(Directory.GetCurrentDirectory(), "unity", "com.noisemaker.hlsl", "Effects");
                if (!Directory.Exists(effectsDir))
                {
                    effectsDir = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "unity", "com.noisemaker.hlsl", "Effects"));
                }
                var reg = EffectRegistry.LoadFromDirectory(effectsDir);
                var effect = reg.GetOp("render.renderLandscape3d");
                Check(effect != null, "render.renderLandscape3d op registered");
                if (effect != null && effect.Effect != null)
                {
                    var globals = effect.Effect.Globals;
                    Check(globals != null && globals.Has("filtering"), "renderLandscape3d has filtering global");
                    var filtering = globals.Get("filtering");
                    Check(filtering.Get("define").AsString == "FILTERING", "filtering define is FILTERING");
                    Check(filtering.Get("default").AsNumber == 1.0, "filtering default is 1");
                    var choices = filtering.Get("choices");
                    Check(choices != null && choices.Get("isosurface").AsNumber == 0.0, "filtering isosurface is 0");
                    Check(choices != null && choices.Get("voxel").AsNumber == 1.0, "filtering voxel is 1");
                }

                // Default filtering (1 -> voxel)
                string dslDefault = "search synth3d, render\nshape3d().renderLandscape3d().write(o0)\nrender(o0)\n";
                var graphDefault = DslCompiler.Compile(dslDefault, reg);
                var passDefault = graphDefault.Passes.Find(p => p.EffectKey == "render.renderLandscape3d");
                Check(passDefault != null, "passDefault exists");
                Check(passDefault != null && passDefault.Defines["FILTERING"] == 1, "default filtering define is 1");

                // Explicit isosurface (0)
                string dslIso = "search synth3d, render\nshape3d().renderLandscape3d(filtering: isosurface).write(o0)\nrender(o0)\n";
                var graphIso = DslCompiler.Compile(dslIso, reg);
                var passIso = graphIso.Passes.Find(p => p.EffectKey == "render.renderLandscape3d");
                Check(passIso != null, "passIso exists");
                Check(passIso != null && passIso.Defines["FILTERING"] == 0, "isosurface filtering define is 0");

                // Explicit voxel (1)
                string dslVoxel = "search synth3d, render\nshape3d().renderLandscape3d(filtering: voxel).write(o0)\nrender(o0)\n";
                var graphVoxel = DslCompiler.Compile(dslVoxel, reg);
                var passVoxel = graphVoxel.Passes.Find(p => p.EffectKey == "render.renderLandscape3d");
                Check(passVoxel != null, "passVoxel exists");
                Check(passVoxel != null && passVoxel.Defines["FILTERING"] == 1, "voxel filtering define is 1");
            }
            catch (Exception ex)
            {
                Check(false, "TestRenderLandscape3dFilteringDefines: " + ex.Message);
            }
        }

        // GAP-004 (noisemaker declared range 4891b9953f9f..2f47612c2904; the
        // unported shader delta synced here is 9d3474df..2f47612c2904, with the
        // policies introduced by a021a283): definition-level mipmaps /
        // persistent / 3D-filter texture policies. The C# compiler carries them as
        // data only (the executor keeps its engine-wide NEAREST / single-mip /
        // no-preserve defaults); placement follows compiler.js extractTextureSpecs().
        private static void TestGap004TexturePolicyContract()
        {
            var reg = new EffectRegistry();
            // 2D texture declaring mipmaps + persistent; 3D texture declaring filter.
            reg.Register(JsonValue.Parse(
                "{\"name\":\"Mip Probe\",\"namespace\":\"synth\",\"func\":\"mipProbe\",\"starter\":false," +
                "\"globals\":{},\"passes\":[{\"name\":\"render\",\"program\":\"automationProbe\"," +
                "\"inputs\":{},\"outputs\":{\"fragColor\":\"outputTex\"}}]," +
                "\"textures\":{\"_feedback\":{\"width\":\"input\",\"height\":\"input\"," +
                "\"format\":\"rgba16f\",\"mipmaps\":true,\"persistent\":true}}}"));
            reg.Register(JsonValue.Parse(
                "{\"name\":\"Filter 3D Probe\",\"namespace\":\"synth3d\",\"func\":\"filter3dProbe\"," +
                "\"starter\":false,\"globals\":{},\"passes\":[{\"name\":\"render\"," +
                "\"program\":\"automationProbe\",\"inputs\":{},\"outputs\":{\"fragColor\":\"outputTex\"}}]," +
                "\"textures3d\":{\"_vol\":{\"width\":\"input\",\"height\":\"input\",\"depth\":\"input\"," +
                "\"format\":\"rgba16f\",\"filter\":\"linear\"}}}"));
            // Edge case mirroring compiler.js extractTextureSpecs: a 2D-map entry
            // that authors is3D:true is treated as 3D by extractTextureSpecs (which
            // keys on effectSpec.is3D) — filter carries, mipmaps/persistent do not.
            reg.Register(JsonValue.Parse(
                "{\"name\":\"Edge 3D Probe\",\"namespace\":\"synth\",\"func\":\"edge3dProbe\"," +
                "\"starter\":false,\"globals\":{},\"passes\":[{\"name\":\"render\"," +
                "\"program\":\"automationProbe\",\"inputs\":{},\"outputs\":{\"fragColor\":\"outputTex\"}}]," +
                "\"textures\":{\"_edge\":{\"width\":\"input\",\"height\":\"input\",\"depth\":\"input\"," +
                "\"is3D\":true,\"format\":\"rgba16f\",\"filter\":\"nearest\"}}}"));

            // 2D: mipmaps/persistent propagate from the definition into the graph model.
            RenderGraph g2d = DslCompiler.Compile(
                "search synth\nmipProbe().write(o0)\nrender(o0)\n", reg);
            string texId2d = null;
            foreach (var kv in g2d.Textures)
                if (kv.Key.Contains("_feedback")) { texId2d = kv.Key; break; }
            Check(texId2d != null, "GAP-004 2D texture spec present in graph");
            if (texId2d != null)
            {
                TextureSpec spec = g2d.Textures[texId2d];
                Check(spec.Mipmaps == true, "GAP-004 2D mipmaps propagated");
                Check(spec.Persistent == true, "GAP-004 2D persistent propagated");
                Check(spec.Filter == null, "GAP-004 2D spec carries no filter");
            }
            string json2d = DslCompiler.ToNormalizedJson(g2d);
            Check(json2d.Contains("\"mipmaps\":true,\"persistent\":true"),
                "GAP-004 normalized graph emits mipmaps+persistent in key order");

            // 3D: filter propagates from textures3d into the graph model.
            RenderGraph g3d = DslCompiler.Compile(
                "search synth3d\nfilter3dProbe().write(o0)\nrender(o0)\n", reg);
            string texId3d = null;
            foreach (var kv in g3d.Textures)
                if (kv.Key.Contains("_vol")) { texId3d = kv.Key; break; }
            Check(texId3d != null, "GAP-004 3D texture spec present in graph");
            if (texId3d != null)
            {
                TextureSpec spec3d = g3d.Textures[texId3d];
                Check(spec3d.Is3D, "GAP-004 3D spec is3D");
                Check(spec3d.Filter == "linear", "GAP-004 3D filter carried");
                Check(!spec3d.Mipmaps.HasValue && !spec3d.Persistent.HasValue,
                    "GAP-004 3D spec carries no mipmaps/persistent");
            }
            string json3d = DslCompiler.ToNormalizedJson(g3d);
            Check(json3d.Contains("\"is3D\":true,\"filter\":\"linear\""),
                "GAP-004 normalized graph emits filter after is3D in key order");

            // Edge: 2D-map entry authoring is3D:true + filter behaves like the 3D
            // branch (extractTextureSpecs keys on effectSpec.is3D).
            RenderGraph gEdge = DslCompiler.Compile(
                "search synth\nedge3dProbe().write(o0)\nrender(o0)\n", reg);
            string texIdEdge = null;
            foreach (var kv in gEdge.Textures)
                if (kv.Key.Contains("_edge")) { texIdEdge = kv.Key; break; }
            Check(texIdEdge != null, "GAP-004 edge texture spec present in graph");
            if (texIdEdge != null)
            {
                TextureSpec specEdge = gEdge.Textures[texIdEdge];
                Check(specEdge.Is3D, "GAP-004 edge spec is3D from authored flag");
                Check(specEdge.Filter == "nearest", "GAP-004 edge spec carries filter");
                Check(!specEdge.Mipmaps.HasValue && !specEdge.Persistent.HasValue,
                    "GAP-004 edge spec carries no mipmaps/persistent");
            }

            // GraphLoader round-trip: graph JSON declares the fields; loader parses them.
            string loaderJson = "{\"passes\":[],\"textures\":{" +
                "\"_mip\":{\"width\":128,\"height\":128,\"format\":\"rgba16f\"," +
                "\"usage\":[\"render\",\"sample\",\"copySrc\",\"copyDst\"]," +
                "\"mipmaps\":true,\"persistent\":false}," +
                "\"_vol\":{\"width\":\"screen\",\"height\":\"screen\",\"format\":\"rgba16f\"," +
                "\"usage\":[\"storage\",\"sample\",\"copySrc\",\"copyDst\"],\"depth\":64," +
                "\"is3D\":true,\"filter\":\"nearest\"}}}";
            RenderGraph loaded = RenderGraph.FromJson(loaderJson);
            TextureSpec mip = loaded.Textures["_mip"];
            Check(mip.Mipmaps == true, "GAP-004 loader parses 2D mipmaps");
            Check(mip.Persistent == false, "GAP-004 loader parses explicit 2D persistent:false");
            TextureSpec vol = loaded.Textures["_vol"];
            Check(vol.Filter == "nearest", "GAP-004 loader parses 3D filter");
            Check(vol.Is3D, "GAP-004 loader parses 3D is3D");

            // Negative placement: filter is 3D-only in the loader too — a
            // hand-authored 2D spec with "filter" must not be parsed.
            string negJson = "{\"passes\":[],\"textures\":{" +
                "\"_bad\":{\"width\":64,\"height\":64,\"format\":\"rgba16f\"," +
                "\"usage\":[\"render\",\"sample\",\"copySrc\",\"copyDst\"]," +
                "\"filter\":\"linear\"}}}";
            TextureSpec bad = RenderGraph.FromJson(negJson).Textures["_bad"];
            Check(bad.Filter == null, "GAP-004 loader rejects 2D filter placement");
            string neg3dJson = "{\"passes\":[],\"textures\":{" +
                "\"_bad3d\":{\"width\":32,\"height\":32,\"format\":\"rgba16f\"," +
                "\"usage\":[\"storage\",\"sample\",\"copySrc\",\"copyDst\"],\"depth\":16," +
                "\"is3D\":true,\"mipmaps\":true}}}";
            TextureSpec bad3d = RenderGraph.FromJson(neg3dJson).Textures["_bad3d"];
            Check(!bad3d.Mipmaps.HasValue, "GAP-004 loader rejects 3D mipmaps placement");
            // Whitelist: only "nearest"/"linear" pass the loader (validator parity).
            string negValJson = "{\"passes\":[],\"textures\":{" +
                "\"_badval\":{\"width\":32,\"height\":32,\"format\":\"rgba16f\"," +
                "\"usage\":[\"storage\",\"sample\",\"copySrc\",\"copyDst\"],\"depth\":16," +
                "\"is3D\":true,\"filter\":\"trilinear\"}}}";
            TextureSpec badval = RenderGraph.FromJson(negValJson).Textures["_badval"];
            Check(badval.Filter == null, "GAP-004 loader whitelist rejects unknown filter");
        }

        private static RenderGraph CompileProbe(string body)
        {
            string source = "search synth\n" + body + "\nrender(o0)\n";
            return DslCompiler.Compile(source, ProbeRegistry());
        }

        private static EffectRegistry ProbeRegistry()
        {
            var reg = new EffectRegistry();
            reg.Register(JsonValue.Parse(
                "{\"name\":\"Automation Probe\",\"namespace\":\"synth\"," +
                "\"func\":\"automationProbe\",\"starter\":true,\"globals\":{" +
                "\"amount\":{\"type\":\"float\",\"default\":0,\"uniform\":\"amount\"," +
                "\"min\":0,\"max\":100}},\"passes\":[{\"name\":\"render\"," +
                "\"program\":\"automationProbe\",\"inputs\":{},\"outputs\":{" +
                "\"fragColor\":\"outputTex\"}}],\"textures\":{}}"));
            reg.Register(JsonValue.Parse(
                "{\"name\":\"Diag Filter\",\"namespace\":\"synth\"," +
                "\"func\":\"diagFilter\",\"starter\":false,\"globals\":{}," +
                "\"passes\":[{\"name\":\"render\"," +
                "\"program\":\"diagFilter\",\"inputs\":{\"source\":\"inputTex\"},\"outputs\":{" +
                "\"fragColor\":\"outputTex\"}}],\"textures\":{}}"));
            return reg;
        }

        private static void CheckApprox(double actual, double expected, double tolerance, string label)
        {
            Check(Math.Abs(actual - expected) <= tolerance,
                label + " (expected " + expected + ", got " + actual + ")");
        }

        private static double PositiveModulo(double value, double modulus)
        {
            double remainder = value % modulus;
            return remainder < 0 ? remainder + modulus : remainder;
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
