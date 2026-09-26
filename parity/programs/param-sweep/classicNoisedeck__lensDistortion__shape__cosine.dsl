search classicNoisedeck

noise(seed: 1, ridges: true)
  .lensDistortion(shape: cosine)
  .write(o0)

render(o0)
