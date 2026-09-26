search filter, synth

noise(seed: 1, ridges: true)
  .convolutionFeedback(blurRadius: 6)
  .write(o0)

render(o0)
