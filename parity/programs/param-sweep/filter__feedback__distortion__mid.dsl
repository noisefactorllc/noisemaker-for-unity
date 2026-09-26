search filter, synth

noise(seed: 1, ridges: true)
  .feedback(distortion: 100)
  .write(o0)

render(o0)
