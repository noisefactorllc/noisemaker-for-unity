search filter, synth

noise(seed: 1, ridges: true)
  .corrupt(scatter: 50)
  .write(o0)

render(o0)
