search filter, synth

noise(seed: 1, ridges: true)
  .morphology(shape: round)
  .write(o0)

render(o0)
