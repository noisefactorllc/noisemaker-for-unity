search filter, synth

noise(seed: 1, ridges: true)
  .dither(threshold: 0.5)
  .write(o0)

render(o0)
