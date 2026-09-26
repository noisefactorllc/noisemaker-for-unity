search filter, synth

noise(seed: 1, ridges: true)
  .corrupt(shift: 100)
  .write(o0)

render(o0)
