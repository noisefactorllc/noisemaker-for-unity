search filter, synth

noise(seed: 1, ridges: true)
  .scanlineError(distortion: 1.5)
  .write(o0)

render(o0)
