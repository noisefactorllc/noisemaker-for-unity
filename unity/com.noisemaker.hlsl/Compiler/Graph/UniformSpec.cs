// UniformSpec.cs — consumer range for %-automation scaling.
//
// reference/03 §2.1 / reference/04 §10.4: pass.uniformSpecs maps uniformName ->
// { min, max }. Used to scale a normalized 0..1 oscillator/midi/audio percent into
// the uniform's real range: value = min + pct*(max-min). Doubles to match JS.

namespace Noisemaker.Hlsl.Compiler.Graph
{
    public sealed class UniformSpec
    {
        public double Min { get; set; }
        public double Max { get; set; }
        // False only for a conditionalUniforms entry (reference 0ed489ec) whose global
        // declares no min/max (e.g. blendMode: choices but no explicit range) — the
        // reference emits `{type:"int"}` alone then (`Number.isFinite(def.min) &&
        // Number.isFinite(def.max)` guards the min/max assignment). True everywhere else;
        // Min/Max are meaningless when false and must not be serialized.
        public bool HasRange { get; set; } = true;
        // "int" for a compile-time-selector uniform automation must round to (reference
        // 0ed489ec conditionalUniforms — a `choices`-bearing int global referenced by a
        // pass's conditions.runIf/skipIf, e.g. viewMode). Null for the ordinary case.
        public string Type { get; set; }
    }
}
