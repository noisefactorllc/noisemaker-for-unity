search points, synth, render

perlin()
  .pointsEmit(stateSize: 512)
  .buddhabrot(stateSize: 513)
  .pointsRender(intensity: 99)
  .write(o0)

render(o0)
