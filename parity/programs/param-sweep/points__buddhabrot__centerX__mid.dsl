search points, synth, render

perlin()
  .pointsEmit(stateSize: 512)
  .buddhabrot(centerX: 0)
  .pointsRender(intensity: 99)
  .write(o0)

render(o0)
