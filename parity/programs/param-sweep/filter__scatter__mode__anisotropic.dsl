search filter, synth

noise(seed: 1, ridges: true)
  .scatter(mode: anisotropic)
  .write(o0)

render(o0)
