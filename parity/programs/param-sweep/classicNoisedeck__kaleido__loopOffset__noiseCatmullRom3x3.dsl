search classicNoisedeck

noise(seed: 1, ridges: true)
  .kaleido(loopOffset: noiseCatmullRom3x3)
  .write(o0)

render(o0)
