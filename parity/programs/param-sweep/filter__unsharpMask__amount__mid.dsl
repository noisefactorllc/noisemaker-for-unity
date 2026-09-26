search filter, synth

noise(seed: 1, ridges: true)
  .unsharpMask(amount: 250)
  .write(o0)

render(o0)
