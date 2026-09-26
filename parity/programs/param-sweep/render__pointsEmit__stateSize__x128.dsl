search points, synth, render

perlin()
  .pointsEmit(stateSize: x128)
  .physical()
  .pointsRender()
  .write(o0)

render(o0)
