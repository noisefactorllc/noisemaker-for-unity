search synth, mixer

testPattern(pattern: colorBars).write(o1)
testPattern(pattern: gradient).write(o2)
read(o1).shapeMask(tex: read(o2), shape: triangle, rotation: 30).write(o0)
render(o0)