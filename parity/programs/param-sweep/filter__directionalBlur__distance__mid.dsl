search filter, synth

noise(seed: 1, ridges: true)
  .directionalBlur(distance: 100.5)
  .write(o0)

render(o0)
