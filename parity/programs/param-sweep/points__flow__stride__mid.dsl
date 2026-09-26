search points, synth, render

perlin()
  .pointsEmit()
  .flow(stride: 500.5)
  .pointsRender()
  .write(o0)

render(o0)
