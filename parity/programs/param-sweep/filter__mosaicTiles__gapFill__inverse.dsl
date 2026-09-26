search filter, synth

noise(seed: 1, ridges: true)
  .mosaicTiles(gapFill: inverse)
  .write(o0)

render(o0)
