search filter, synth

noise(seed: 1, ridges: true)
  .scanlineError(timeOffset: 10)
  .write(o0)

render(o0)
