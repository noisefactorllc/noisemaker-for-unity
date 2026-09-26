search points, synth, render

perlin()
  .pointsEmit()
  .physical()
  .pointsRender(viewScale: 5.05)
  .write(o0)

render(o0)
