search filter, synth

noise(seed: 1, ridges: true)
  .corrupt(bits: 50)
  .write(o0)

render(o0)
