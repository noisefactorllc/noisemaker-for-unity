search filter, synth

noise(seed: 1, ridges: true)
  .dither(palette: zxSpectrum)
  .write(o0)

render(o0)
