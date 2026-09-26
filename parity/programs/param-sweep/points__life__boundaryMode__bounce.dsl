search points, synth, render

perlin()
  .pointsEmit()
  .life(boundaryMode: bounce)
  .pointsRender()
  .write(o0)

render(o0)
