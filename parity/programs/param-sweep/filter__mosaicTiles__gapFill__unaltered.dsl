search filter, synth

noise(seed: 1, ridges: true)
  .mosaicTiles(gapFill: unaltered, mode: shifted)
  .write(o0)

render(o0)
