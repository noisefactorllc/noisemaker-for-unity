search points, synth, render

perlin()
  .pointsEmit()
  .flock(boundaryMode: softWall)
  .pointsRender()
  .write(o0)

render(o0)
