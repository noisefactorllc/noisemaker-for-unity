search filter, synth

noise(seed: 1, ridges: true)
  .morphology(mode: erode)
  .write(o0)

render(o0)
