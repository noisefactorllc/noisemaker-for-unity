search points, synth, render

perlin()
  .pointsEmit(layout: spiral)
  .physical()
  .pointsRender()
  .write(o0)

render(o0)
