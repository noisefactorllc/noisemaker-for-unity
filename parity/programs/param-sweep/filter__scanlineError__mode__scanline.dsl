search filter, synth

noise(seed: 1, ridges: true)
  .scanlineError(mode: scanline)
  .write(o0)

render(o0)
