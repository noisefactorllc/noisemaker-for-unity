search filter, synth

noise(seed: 1, ridges: true)
  .zoomBlur(strength: 1)
  .write(o0)

render(o0)
