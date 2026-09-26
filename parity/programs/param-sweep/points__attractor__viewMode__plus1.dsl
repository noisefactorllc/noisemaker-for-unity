search points, synth, render

perlin()
  .pointsEmit()
  .attractor(viewMode: 2)
  .pointsRender(viewMode: 1)
  .write(o0)

render(o0)
