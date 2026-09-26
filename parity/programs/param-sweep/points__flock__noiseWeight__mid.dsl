search points, synth, render

perlin()
  .pointsEmit()
  .flock(noiseWeight: 0.5)
  .pointsRender()
  .write(o0)

render(o0)
