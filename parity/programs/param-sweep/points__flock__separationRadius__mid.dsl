search points, synth, render

perlin()
  .pointsEmit()
  .flock(separationRadius: 52.5)
  .pointsRender()
  .write(o0)

render(o0)
