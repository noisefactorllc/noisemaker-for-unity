search points, synth, render

perlin()
  .pointsEmit()
  .flock(separation: 2.5)
  .pointsRender()
  .write(o0)

render(o0)
