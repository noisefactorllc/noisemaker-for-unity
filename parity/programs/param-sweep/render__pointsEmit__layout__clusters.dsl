search points, synth, render

perlin()
  .pointsEmit(layout: clusters)
  .physical()
  .pointsRender()
  .write(o0)

render(o0)
