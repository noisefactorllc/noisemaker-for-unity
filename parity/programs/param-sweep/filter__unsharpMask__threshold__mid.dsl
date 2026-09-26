search filter, synth

noise(seed: 1, ridges: true)
  .unsharpMask(threshold: 50)
  .write(o0)

render(o0)
