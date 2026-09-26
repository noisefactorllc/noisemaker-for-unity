search points, synth, render

perlin()
  .pointsEmit()
  .physical(drag: 0.1)
  .pointsRender()
  .write(o0)

render(o0)
