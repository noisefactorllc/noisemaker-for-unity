search points, synth, render

perlin()
  .pointsEmit()
  .attractor(attractor: halvorsen)
  .pointsRender(viewMode: 1)
  .write(o0)

render(o0)
