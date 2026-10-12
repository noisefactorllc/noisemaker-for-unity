search synth, mixer

testPattern(pattern: colorBars).write(o1)
solid(color: #804020, alpha: 0.5).write(o2)
read(o1).blendMode(tex: read(o2), mode: multiply, mix: 0).write(o0)
render(o0)