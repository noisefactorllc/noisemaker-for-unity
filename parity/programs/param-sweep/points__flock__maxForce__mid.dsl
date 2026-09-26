search points, synth, render

perlin()
  .pointsEmit()
  .flock(maxForce: 0.505)
  .pointsRender()
  .write(o0)

render(o0)
