search filter, synth

noise(seed: 1, ridges: true)
  .highPass(mono: true)
  .write(o0)

render(o0)
