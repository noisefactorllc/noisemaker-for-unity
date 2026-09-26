search points, synth, render

perlin()
  .pointsEmit(stateSize: x2048)
  .physical()
  .pointsRender()
  .write(o0)

render(o0)
