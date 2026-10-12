search filter, synth

noise(seed: 1, ridges: true)
  .edge(contourSide: upper, kernel: contour)
  .write(o0)

render(o0)
