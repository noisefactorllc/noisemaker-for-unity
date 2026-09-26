search filter, synth

noise(seed: 1, ridges: true)
  .convolutionFeedback(sharpenAmount: 1.5)
  .write(o0)

render(o0)
