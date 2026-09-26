search filter, synth

noise(seed: 1, ridges: true)
  .highPass(radius: 50.25)
  .write(o0)

render(o0)
