search points, synth, render

perlin()
  .pointsEmit()
  .flock(cohesion: 2.5)
  .pointsRender()
  .write(o0)

render(o0)
