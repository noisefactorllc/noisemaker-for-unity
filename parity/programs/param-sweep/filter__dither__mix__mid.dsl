search filter, synth

noise(seed: 1, ridges: true)
  .dither(mix: 0.5)
  .write(o0)

render(o0)
