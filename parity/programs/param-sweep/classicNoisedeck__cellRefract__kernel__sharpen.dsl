search classicNoisedeck

noise(seed: 1, ridges: true)
  .cellRefract(kernel: sharpen)
  .write(o0)

render(o0)
