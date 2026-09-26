search filter, synth

noise(seed: 1, ridges: true)
  .sobel(amount: 2.55)
  .write(o0)

render(o0)
