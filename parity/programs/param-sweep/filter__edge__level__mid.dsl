search filter, synth

noise(seed: 1, ridges: true)
  .edge(level: 100, kernel: contour)
  .write(o0)

render(o0)
