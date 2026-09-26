search filter, synth

noise(seed: 1, ridges: true)
  .step(threshold: 1)
  .write(o0)

render(o0)
