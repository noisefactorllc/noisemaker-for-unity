search filter, synth

noise(seed: 1, ridges: true)
  .feedback(blendMode: subtract)
  .write(o0)

render(o0)
