using System;
using System.Collections.Generic;
using System.Diagnostics;
using Noisemaker.Hlsl.Compiler.Graph;

namespace Noisemaker.Hlsl
{
    public sealed class AudioInputRequirement
    {
        public string Id { get; internal set; }
        public string Name { get; internal set; }
        public int Channel { get; internal set; }
        public bool NeedsRaw { get; internal set; }
    }

    public sealed class AudioInputRequirements
    {
        public bool NeedsLegacy { get; internal set; }
        public bool NeedsLegacyRaw { get; internal set; }
        public List<AudioInputRequirement> Selected { get; } =
            new List<AudioInputRequirement>();
    }

    public static class Automation
    {
        private const int MaxDepth = 8;
        private const double Tau = Math.PI * 2.0;

        private static readonly double[][] IntegrationNodes =
        {
            new[]
            {
                -0.9894009349916499, -0.9445750230732326, -0.8656312023878318,
                -0.755404408355003, -0.6178762444026438, -0.4580167776572274,
                -0.2816035507792589, -0.0950125098376374, 0.0950125098376374,
                0.2816035507792589, 0.4580167776572274, 0.6178762444026438,
                0.755404408355003, 0.8656312023878318, 0.9445750230732326,
                0.9894009349916499
            },
            new[]
            {
                -0.9602898564975363, -0.7966664774136267, -0.525532409916329,
                -0.1834346424956498, 0.1834346424956498, 0.525532409916329,
                0.7966664774136267, 0.9602898564975363
            },
            new[] { -0.8611363115940526, -0.3399810435848563,
                0.3399810435848563, 0.8611363115940526 },
            new[] { -0.5773502691896257, 0.5773502691896257 }
        };

        private static readonly double[][] IntegrationWeights =
        {
            new[]
            {
                0.0271524594117541, 0.0622535239386479, 0.0951585116824928,
                0.1246289712555339, 0.1495959888165767, 0.1691565193950025,
                0.1826034150449236, 0.1894506104550685, 0.1894506104550685,
                0.1826034150449236, 0.1691565193950025, 0.1495959888165767,
                0.1246289712555339, 0.0951585116824928, 0.0622535239386479,
                0.0271524594117541
            },
            new[]
            {
                0.1012285362903763, 0.2223810344533745, 0.3137066458778873,
                0.362683783378362, 0.362683783378362, 0.3137066458778873,
                0.2223810344533745, 0.1012285362903763
            },
            new[] { 0.3478548451374538, 0.6521451548625461,
                0.6521451548625461, 0.3478548451374538 },
            new[] { 1.0, 1.0 }
        };

        public static double Evaluate(JsonValue config, double normalizedTime,
            UniformSpec consumerRange = null, MidiState midiState = null,
            AudioState audioState = null, double? wallTimeMilliseconds = null)
        {
            return Evaluate(config, normalizedTime, consumerRange, midiState, audioState,
                wallTimeMilliseconds ?? CurrentMilliseconds(), 0, new HashSet<JsonValue>());
        }

        public static AudioInputRequirements GetAudioInputRequirements(
            IReadOnlyList<Pass> passes, Func<Pass, bool> effectNeedsLegacyAudio = null)
        {
            var requirements = new AudioInputRequirements();
            var selected = new Dictionary<string, AudioInputRequirement>();
            var visited = new HashSet<JsonValue>();
            if (passes != null)
                foreach (Pass pass in passes)
                {
                    if (pass.RequiresLegacyAudio ||
                        (effectNeedsLegacyAudio != null && effectNeedsLegacyAudio(pass)))
                        requirements.NeedsLegacy = true;
                    foreach (var uniform in pass.Uniforms)
                        if (uniform.Value.Kind == UniformValueKind.Object)
                            VisitAudio(uniform.Value.Object, requirements, selected, visited);
                }
            return requirements;
        }

        internal static int ResolveRepeatCount(Pass pass, double normalizedTime,
            Func<string, double?> uniformLookup, MidiState midiState,
            AudioState audioState, double wallTimeMilliseconds)
        {
            Repeat repeat = pass != null ? pass.Repeat : null;
            if (repeat == null) return 1;
            if (repeat.IsCount) return Math.Max(1, repeat.Count);

            double? value = uniformLookup != null
                ? uniformLookup(repeat.UniformName) : null;
            if (!value.HasValue)
            {
                UniformValue uniform;
                if (pass.Uniforms.TryGetValue(repeat.UniformName, out uniform))
                {
                    if (uniform.Kind == UniformValueKind.Number)
                        value = uniform.Number;
                    else if (uniform.Kind == UniformValueKind.Object)
                    {
                        UniformSpec range = null;
                        pass.UniformSpecs.TryGetValue(repeat.UniformName, out range);
                        value = Evaluate(uniform.Object, normalizedTime, range,
                            midiState, audioState, wallTimeMilliseconds);
                    }
                }
            }
            return value.HasValue && IsFinite(value.Value)
                ? Math.Max(1, (int)Math.Floor(value.Value)) : 1;
        }

        internal static double? NumberField(JsonValue value, string key)
        {
            JsonValue field = value != null ? value.Get(key) : null;
            return field != null && field.Kind == JsonKind.Number
                ? (double?)field.AsNumber : null;
        }

        internal static string StringField(JsonValue value, string key)
        {
            JsonValue field = value != null ? value.Get(key) : null;
            return field != null && field.Kind == JsonKind.String ? field.AsString : null;
        }

        private static double Evaluate(JsonValue config, double normalizedTime,
            UniformSpec range, MidiState midiState, AudioState audioState,
            double wallTimeMilliseconds, int depth, HashSet<JsonValue> stack)
        {
            if (!IsAutomation(config) || depth > MaxDepth || stack.Contains(config))
                return Scale(0, range);
            stack.Add(config);
            double value;
            try
            {
                string type = AutomationType(config);
                if (type == "Oscillator")
                    value = EvaluateOscillator(config, normalizedTime, midiState, audioState,
                        wallTimeMilliseconds, depth, stack);
                else if (type == "Midi")
                {
                    double min = ResolveField(config.Get("min"), normalizedTime,
                        0, 1, 0, midiState, audioState, wallTimeMilliseconds, depth, stack);
                    double max = ResolveField(config.Get("max"), normalizedTime,
                        0, 1, 1, midiState, audioState, wallTimeMilliseconds, depth, stack);
                    double sensitivity = ResolveField(config.Get("sensitivity"), normalizedTime,
                        0, 10, 1, midiState, audioState, wallTimeMilliseconds, depth, stack);
                    value = EvaluateMidi(config,
                        midiState != null ? midiState.GetPortState(config) : null,
                        wallTimeMilliseconds, min, max, sensitivity);
                }
                else if (BoolField(config, "_invalid"))
                    value = NumberField(config, "min") ?? 0;
                else
                {
                    double min = ResolveField(config.Get("min"), normalizedTime,
                        0, 1, 0, midiState, audioState, wallTimeMilliseconds, depth, stack);
                    double max = ResolveField(config.Get("max"), normalizedTime,
                        0, 1, 1, midiState, audioState, wallTimeMilliseconds, depth, stack);
                    value = EvaluateAudio(config, audioState, min, max);
                }
            }
            finally
            {
                stack.Remove(config);
            }
            return Scale(value, range);
        }

        private static double EvaluateOscillator(JsonValue config, double time,
            MidiState midiState, AudioState audioState, double wallTimeMilliseconds,
            int depth, HashSet<JsonValue> stack)
        {
            int type = (int)(NumberField(config, "oscType") ?? 0);
            double min = ResolveField(config.Get("min"), time, 0, 1, 0,
                midiState, audioState, wallTimeMilliseconds, depth, stack);
            double max = ResolveField(config.Get("max"), time, 0, 1, 1,
                midiState, audioState, wallTimeMilliseconds, depth, stack);
            double offset = ResolveField(config.Get("offset"), time, -1, 1, 0,
                midiState, audioState, wallTimeMilliseconds, depth, stack);
            double seed = ResolveField(config.Get("seed"), time, 1, 9999, 1,
                midiState, audioState, wallTimeMilliseconds, depth, stack);
            JsonValue speedField = config.Get("speed");
            double phase = IsAutomation(speedField)
                ? Integrate(speedField, time, -20, 20, midiState, audioState,
                    wallTimeMilliseconds, depth, stack)
                : time * (FiniteNumber(speedField) ?? 1);
            double raw = Oscillators.EvaluateWave(type, phase + offset, seed);
            return min + raw * (max - min);
        }

        private static double ResolveField(JsonValue field, double time,
            double rangeMin, double rangeMax, double fallback, MidiState midiState,
            AudioState audioState, double wallTimeMilliseconds, int depth,
            HashSet<JsonValue> stack)
        {
            if (IsAutomation(field))
                return Evaluate(field, time, new UniformSpec { Min = rangeMin, Max = rangeMax },
                    midiState, audioState, wallTimeMilliseconds, depth + 1, stack);
            return FiniteNumber(field) ?? fallback;
        }

        private static double Integrate(JsonValue config, double time,
            double rangeMin, double rangeMax, MidiState midiState, AudioState audioState,
            double wallTimeMilliseconds, int depth, HashSet<JsonValue> stack)
        {
            double integral;
            string type = AutomationType(config);
            if (type == "Oscillator" && CanIntegrateExactly(config))
                integral = IntegrateSimpleOscillator(config, time);
            else if ((type == "Midi" || type == "Audio") && !HasDynamicFields(config))
                integral = Evaluate(config, time, null, midiState, audioState,
                    wallTimeMilliseconds, depth + 1, stack) * time;
            else
            {
                int rule = Math.Min(depth, IntegrationNodes.Length - 1);
                double midpoint = time * 0.5;
                double halfWidth = time * 0.5;
                double sum = 0;
                for (int i = 0; i < IntegrationNodes[rule].Length; i++)
                {
                    double sampleTime = midpoint + halfWidth * IntegrationNodes[rule][i];
                    sum += IntegrationWeights[rule][i] * Evaluate(config, sampleTime, null,
                        midiState, audioState, wallTimeMilliseconds, depth + 1, stack);
                }
                integral = halfWidth * sum;
            }
            return rangeMin * time + integral * (rangeMax - rangeMin);
        }

        private static bool CanIntegrateExactly(JsonValue config)
        {
            double? type = NumberField(config, "oscType");
            return type.HasValue && type.Value >= 0 && type.Value <= 4 &&
                FiniteNumber(config.Get("min")).HasValue &&
                FiniteNumber(config.Get("max")).HasValue &&
                FiniteNumber(config.Get("speed")).HasValue &&
                FiniteNumber(config.Get("offset")).HasValue &&
                FiniteNumber(config.Get("seed")).HasValue;
        }

        private static double IntegrateSimpleOscillator(JsonValue config, double time)
        {
            int type = (int)NumberField(config, "oscType").Value;
            double min = NumberField(config, "min").Value;
            double max = NumberField(config, "max").Value;
            double speed = NumberField(config, "speed").Value;
            double offset = NumberField(config, "offset").Value;
            if (speed == 0)
                return (min + Oscillators.EvaluateWave(type, offset,
                    NumberField(config, "seed").Value) * (max - min)) * time;
            double start = OscillatorPrimitive(type, offset);
            double end = OscillatorPrimitive(type, offset + speed * time);
            return min * time + (max - min) * ((end - start) / speed);
        }

        private static double OscillatorPrimitive(int type, double x)
        {
            double whole = Math.Floor(x);
            double fraction = x - whole;
            switch (type)
            {
                case 0: return x * 0.5 - Math.Sin(x * Tau) / (2 * Tau);
                case 1:
                    double partial = fraction < 0.5
                        ? fraction * fraction
                        : 2 * fraction - fraction * fraction - 0.5;
                    return whole * 0.5 + partial;
                case 2: return whole * 0.5 + fraction * fraction * 0.5;
                case 3: return x - (whole * 0.5 + fraction * fraction * 0.5);
                case 4: return whole * 0.5 + Math.Max(0, fraction - 0.5);
                default: return 0;
            }
        }

        private static bool IntegerIn(double? value, int min, int max)
        {
            return value.HasValue && value.Value >= min && value.Value <= max && value.Value == Math.Floor(value.Value);
        }

        private static double EvaluateMidi(JsonValue config, MidiState state,
            double wallTimeMilliseconds, double min, double max, double sensitivity)
        {
            if (BoolField(config, "_invalid") || state == null) return min;
            double modeValue = NumberField(config, "mode") ?? 4;
            int mode = modeValue == Math.Floor(modeValue) ? (int)modeValue : -1;
            bool hasZone = config.Has("zone");
            double? zone = NumberField(config, "zone"), members = NumberField(config, "members"), channelNumber = NumberField(config, "channel");
            if (hasZone && (config.Has("channel") || !IntegerIn(zone, 0, 1))) return min;
            if (config.Has("members") && (!hasZone || !IntegerIn(members, 1, 15))) return min;
            if (!hasZone && modeValue >= 5 && !IntegerIn(channelNumber, 1, 16)) return min;
            MidiNote voice = hasZone ? state.GetZoneVoice((int)zone.Value, members.HasValue ? (int?)members.Value : null) : null;
            if (hasZone && voice == null) return min;
            MidiChannelState channel = voice?.Channel ?? state.GetChannel(IntegerIn(channelNumber, 1, 16) ? (int)channelNumber.Value : 1);
            int key = voice?.Key ?? channel.Key, velocity = voice?.Velocity ?? channel.Velocity;
            int gate = voice != null ? 1 : channel.Gate;
            double timestamp = voice?.TimeMilliseconds ?? channel.TimeMilliseconds;
            double raw = 0, divisor = 127.0;
            switch (mode)
            {
                case 0: raw = key; break;
                case 1: if (gate == 1) raw = key; break;
                case 2: if (gate == 1) raw = velocity; break;
                case 5:
                case 6:
                    double? cc = config.Get("cc") == null || config.Get("cc").IsNull ? 1 : NumberField(config, "cc");
                    if (!IntegerIn(cc, 0, mode == 6 ? 31 : 127)) return min;
                    raw = mode == 6 ? channel.Cc14[(int)cc.Value] : channel.Cc[(int)cc.Value];
                    divisor = mode == 6 ? 16383.0 : 127.0;
                    break;
                case 7:
                    double? nrpn = NumberField(config, "nrpn");
                    if (!IntegerIn(nrpn, 0, 16382)) return min;
                    channel.Nrpn.TryGetValue((int)nrpn.Value, out int parameter);
                    raw = parameter; divisor = 16383.0; break;
                case 8: raw = channel.PitchBend; divisor = 16383.0; break;
                case 9: raw = channel.Pressure; break;
                case 10: raw = key >= 0 && key <= 127 ? channel.PolyPressure[key] : 0; break;
                case 3:
                case 4:
                default:
                    if (gate == 1)
                    {
                        raw = mode == 3 ? key : velocity;
                        double decay = Math.Min(1, (wallTimeMilliseconds - timestamp) * sensitivity * 0.001);
                        raw *= 1 - decay;
                    }
                    break;
            }
            return min + (raw / divisor) * (max - min);
        }

        internal static bool HasAudioSelector(JsonValue value)
        {
            JsonValue source = value?.Get("_ast");
            if (StringField(source, "type") != "Audio") source = value;
            foreach (string field in new[] { "name", "id", "channel" })
                if ((value?.Has(field) ?? false) || (source?.Has(field) ?? false)) return true;
            return false;
        }

        internal static bool ValidAudioSelector(JsonValue value)
        {
            if (value == null) return false;
            JsonValue source = value.Get("_ast");
            if (StringField(source, "type") != "Audio") source = value;
            foreach (string field in new[] { "name", "id", "channel" })
                if ((source?.Has(field) ?? false) && !value.Has(field)) return false;
            foreach (string field in new[] { "name", "id" })
                if (value.Has(field) && string.IsNullOrEmpty(StringField(value, field))) return false;
            if (value.Has("id") && !value.Has("name")) return false;
            return IntegerIn(NumberField(value, "channel"), 1, 32);
        }

        private static double EvaluateAudio(JsonValue config, AudioState state,
            double min, double max)
        {
            if (BoolField(config, "_invalid") || state == null) return min;
            bool selected = HasAudioSelector(config);
            if (selected && !ValidAudioSelector(config)) return min;
            AudioState source = selected ? state.GetDeviceChannelState(config) : state;
            if (source == null) return min;
            int band = (int)(NumberField(config, "band") ?? -1);
            double raw;
            switch (band)
            {
                case 0: raw = source.Low; break;
                case 1: raw = source.Mid; break;
                case 2: raw = source.High; break;
                case 3: raw = source.Vol; break;
                case 4:
                    if (!source.RawReady) return min;
                    raw = (Math.Max(-1, Math.Min(1, source.Raw)) + 1) * 0.5;
                    break;
                default: raw = 0; break;
            }
            raw = Math.Max(0, Math.Min(1, raw));
            return min + raw * (max - min);
        }

        private static bool IsAutomation(JsonValue value)
        {
            string type = AutomationType(value);
            return type == "Oscillator" || type == "Midi" || type == "Audio";
        }

        private static string AutomationType(JsonValue value)
        {
            if (value == null || value.Kind != JsonKind.Object) return null;
            string type = StringField(value, "type");
            if (type != null) return type;
            JsonValue ast = value.Get("_ast");
            return StringField(ast, "type");
        }

        private static bool HasDynamicFields(JsonValue config)
        {
            if (IsAutomation(config.Get("min")) || IsAutomation(config.Get("max")))
                return true;
            return AutomationType(config) == "Midi" &&
                IsAutomation(config.Get("sensitivity"));
        }

        private static double Scale(double value, UniformSpec range)
        {
            return range == null || !IsFinite(range.Min) || !IsFinite(range.Max)
                ? value : range.Min + value * (range.Max - range.Min);
        }

        private static double? FiniteNumber(JsonValue value)
        {
            if (value == null || value.Kind != JsonKind.Number || !IsFinite(value.AsNumber))
                return null;
            return value.AsNumber;
        }

        private static bool BoolField(JsonValue value, string key)
        {
            JsonValue field = value != null ? value.Get(key) : null;
            return field != null && field.Kind == JsonKind.Bool && field.AsBool;
        }

        private static bool IsFinite(double value)
        {
            return !double.IsNaN(value) && !double.IsInfinity(value);
        }

        private static double CurrentMilliseconds()
        {
            return (double)Stopwatch.GetTimestamp() * 1000.0 / Stopwatch.Frequency;
        }

        private static void VisitAudio(JsonValue value, AudioInputRequirements requirements,
            Dictionary<string, AudioInputRequirement> selected, HashSet<JsonValue> visited)
        {
            if (value == null || value.Kind != JsonKind.Object || !visited.Add(value)) return;
            if (AutomationType(value) == "Audio")
            {
                bool hasSelectorIntent = HasAudioSelector(value);
                double? band = NumberField(value, "band");
                if (BoolField(value, "_invalid") || !band.HasValue ||
                    band.Value < 0 || band.Value > 4 || band.Value != Math.Floor(band.Value))
                    return;

                VisitAudio(value.Get("min"), requirements, selected, visited);
                VisitAudio(value.Get("max"), requirements, selected, visited);

                string name = StringField(value, "name");
                string id = StringField(value, "id");
                double? channel = NumberField(value, "channel");
                if (ValidAudioSelector(value))
                {
                    string key = (id ?? "") + "\u001f" + name + "\u001f" + channel.Value;
                    AudioInputRequirement requirement;
                    if (!selected.TryGetValue(key, out requirement))
                    {
                        requirement = new AudioInputRequirement
                        {
                            Id = string.IsNullOrEmpty(id) ? null : id,
                            Name = name,
                            Channel = (int)channel.Value,
                            NeedsRaw = band.Value == 4
                        };
                        selected.Add(key, requirement);
                        requirements.Selected.Add(requirement);
                    }
                    else if (band.Value == 4) requirement.NeedsRaw = true;
                }
                else if (!hasSelectorIntent)
                {
                    requirements.NeedsLegacy = true;
                    if (band.Value == 4) requirements.NeedsLegacyRaw = true;
                }
                return;
            }
            foreach (var item in value.AsObject)
                VisitAudio(item.Value, requirements, selected, visited);
        }
    }
}
