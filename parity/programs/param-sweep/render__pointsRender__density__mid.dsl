search points, synth, render

perlin()
  .pointsEmit()
  .physical()
  .pointsRender(density: 100)
  .write(o0)

render(o0)
