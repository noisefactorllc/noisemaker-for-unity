search filter, synth

noise(seed: 1, ridges: true)
  .threshold(sharpness: 1)
  .write(o0)

render(o0)
