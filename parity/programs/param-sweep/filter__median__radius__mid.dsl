search filter, synth

noise(seed: 1, ridges: true)
  .median(radius: 2)
  .write(o0)

render(o0)
