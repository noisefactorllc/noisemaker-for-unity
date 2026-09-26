search filter, synth

noise(seed: 1, ridges: true)
  .edge(kernel: contour)
  .write(o0)

render(o0)
