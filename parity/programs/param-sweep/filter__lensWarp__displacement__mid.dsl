search filter, synth

noise(seed: 1, ridges: true)
  .lensWarp(displacement: 0.125)
  .write(o0)

render(o0)
