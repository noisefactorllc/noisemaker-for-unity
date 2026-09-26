search filter, synth

noise(seed: 1, ridges: true)
  .dither(matrixScale: 5)
  .write(o0)

render(o0)
