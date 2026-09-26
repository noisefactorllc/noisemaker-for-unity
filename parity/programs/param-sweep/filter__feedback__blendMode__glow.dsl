search filter, synth

noise(seed: 1, ridges: true)
  .feedback(blendMode: glow)
  .write(o0)

render(o0)
