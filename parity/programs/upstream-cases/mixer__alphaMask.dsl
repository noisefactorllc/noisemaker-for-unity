search synth, mixer

testPattern(pattern: colorBars).alphaMask(tex: solid(color: #808080), maskMode: true).write(o1)
read(o1).alphaMask(tex: solid(color: #808080), baseTex: solid(color: #0000ff, alpha: 0.25), maskMode: true).write(o2)
solid(color: #804020, alpha: 0.5).alphaMask(tex: read(o2), mix: 0).write(o0)
render(o0)