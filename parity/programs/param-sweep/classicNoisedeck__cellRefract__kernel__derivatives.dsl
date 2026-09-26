search classicNoisedeck

noise(seed: 1, ridges: true)
  .cellRefract(kernel: derivatives)
  .write(o0)

render(o0)
