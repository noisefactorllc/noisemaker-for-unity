search classicNoisedeck

noise(seed: 1, ridges: true)
  .cellRefract(kernel: posterize)
  .write(o0)

render(o0)
