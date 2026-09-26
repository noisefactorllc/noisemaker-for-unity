search points, synth, render

perlin()
  .pointsEmit(stateSize: 512)
  .buddhabrot(centerY: 3)
  .pointsRender(intensity: 99)
  .write(o0)

render(o0)
