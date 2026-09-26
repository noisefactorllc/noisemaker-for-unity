search points, synth, render

perlin()
  .pointsEmit(stateSize: 512)
  .buddhabrot(maxIter: 1010)
  .pointsRender(intensity: 99)
  .write(o0)

render(o0)
