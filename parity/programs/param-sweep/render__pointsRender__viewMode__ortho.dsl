search points, synth, render

perlin()
  .pointsEmit()
  .physical()
  .pointsRender(viewMode: ortho)
  .write(o0)

render(o0)
