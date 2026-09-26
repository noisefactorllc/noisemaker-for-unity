search filter, synth

noise(seed: 1, ridges: true)
  .feedback(blendMode: add)
  .write(o0)

render(o0)
