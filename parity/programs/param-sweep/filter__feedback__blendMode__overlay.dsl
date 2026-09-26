search filter, synth

noise(seed: 1, ridges: true)
  .feedback(blendMode: overlay)
  .write(o0)

render(o0)
