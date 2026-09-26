search filter, synth

noise(seed: 1, ridges: true)
  .sobel(alpha: 0.5)
  .write(o0)

render(o0)
