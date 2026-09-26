search filter, synth

noise(seed: 1, ridges: true)
  .dither(type: bayer2x2)
  .write(o0)

render(o0)
