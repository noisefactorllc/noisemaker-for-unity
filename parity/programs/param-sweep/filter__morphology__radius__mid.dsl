search filter, synth

noise(seed: 1, ridges: true)
  .morphology(radius: 16.5)
  .write(o0)

render(o0)
