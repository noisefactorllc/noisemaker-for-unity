search points, synth, render

perlin()
  .pointsEmit()
  .attractor(stateSize: 257)
  .pointsRender(viewMode: 1)
  .write(o0)

render(o0)
