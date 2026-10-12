search filter, synth

noise(seed: 1, ridges: true)
  .mosaicTiles(gapFill: inverse, mode: shifted)
  .write(o0)

render(o0)
