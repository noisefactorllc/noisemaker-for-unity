search points, synth, render

perlin()
  .pointsEmit()
  .physical()
  .pointsRender(matteOpacity: 0.5)
  .write(o0)

render(o0)
