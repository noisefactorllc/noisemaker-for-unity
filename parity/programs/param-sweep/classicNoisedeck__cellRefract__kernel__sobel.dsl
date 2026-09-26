search classicNoisedeck

noise(seed: 1, ridges: true)
  .cellRefract(kernel: sobel)
  .write(o0)

render(o0)
