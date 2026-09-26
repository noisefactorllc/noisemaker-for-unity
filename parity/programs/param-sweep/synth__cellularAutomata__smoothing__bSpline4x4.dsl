search synth

noise(seed: 1, ridges: true)
  .write(o0)

cellularAutomata(smoothing: bSpline4x4, tex: read(o0))
  .write(o1)

render(o1)
