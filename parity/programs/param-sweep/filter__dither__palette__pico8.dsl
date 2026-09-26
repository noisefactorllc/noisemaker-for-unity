search filter, synth

noise(seed: 1, ridges: true)
  .dither(palette: pico8)
  .write(o0)

render(o0)
