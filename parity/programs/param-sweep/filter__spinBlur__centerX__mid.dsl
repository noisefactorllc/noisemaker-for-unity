search filter, synth

noise(seed: 1, ridges: true)
  .spinBlur(centerX: 1)
  .write(o0)

render(o0)
