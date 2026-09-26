search points, synth, render

perlin()
  .pointsEmit()
  .attractor(speed: 1.005)
  .pointsRender(viewMode: 1)
  .write(o0)

render(o0)
