search filter, synth

noise(seed: 1, ridges: true)
  .dither(type: bayer8x8)
  .write(o0)

render(o0)
