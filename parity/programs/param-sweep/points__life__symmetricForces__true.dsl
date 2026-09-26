search points, synth, render

perlin()
  .pointsEmit()
  .life(symmetricForces: true)
  .pointsRender()
  .write(o0)

render(o0)
