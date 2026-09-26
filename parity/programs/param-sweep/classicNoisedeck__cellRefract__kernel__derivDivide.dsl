search classicNoisedeck

noise(seed: 1, ridges: true)
  .cellRefract(kernel: derivDivide)
  .write(o0)

render(o0)
