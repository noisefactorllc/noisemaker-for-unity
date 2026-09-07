using System;
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
