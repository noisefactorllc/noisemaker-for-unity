search points, synth, render

perlin()
  .pointsEmit(stateSize: x512)
  .physical()
  .pointsRender()
  .write(o0)

render(o0)
