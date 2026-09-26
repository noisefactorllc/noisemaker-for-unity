search filter, synth

noise(seed: 1, ridges: true)
  .convolutionFeedback(blurAmount: 1)
  .write(o0)

render(o0)
