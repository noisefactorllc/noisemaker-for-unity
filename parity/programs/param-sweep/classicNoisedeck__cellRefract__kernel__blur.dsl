search classicNoisedeck

noise(seed: 1, ridges: true)
  .cellRefract(kernel: blur)
  .write(o0)

render(o0)
