search filter, synth

noise(seed: 1, ridges: true)
  .scanlineError(speed: 2.5)
  .write(o0)

render(o0)
