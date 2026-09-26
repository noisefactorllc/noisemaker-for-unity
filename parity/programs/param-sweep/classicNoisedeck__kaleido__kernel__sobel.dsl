search classicNoisedeck

noise(seed: 1, ridges: true)
  .kaleido(kernel: sobel)
  .write(o0)

render(o0)
