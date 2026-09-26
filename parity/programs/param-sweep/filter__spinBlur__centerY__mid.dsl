search filter, synth

noise(seed: 1, ridges: true)
  .spinBlur(centerY: 1)
  .write(o0)

render(o0)
