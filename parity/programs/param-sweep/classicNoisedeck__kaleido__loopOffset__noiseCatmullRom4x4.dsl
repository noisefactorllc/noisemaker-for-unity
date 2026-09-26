search classicNoisedeck

noise(seed: 1, ridges: true)
  .kaleido(loopOffset: noiseCatmullRom4x4)
  .write(o0)

render(o0)
