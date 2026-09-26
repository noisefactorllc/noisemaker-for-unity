search points, synth, render

perlin()
  .pointsEmit()
  .physical(wind: 2)
  .pointsRender()
  .write(o0)

render(o0)
