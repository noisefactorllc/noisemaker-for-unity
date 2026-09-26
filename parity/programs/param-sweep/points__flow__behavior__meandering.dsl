search points, synth, render

perlin()
  .pointsEmit()
  .flow(behavior: meandering)
  .pointsRender()
  .write(o0)

render(o0)
