search points, synth, render

perlin()
  .pointsEmit(stateSize: 512)
  .buddhabrot(zoom: 2.55)
  .pointsRender(intensity: 99)
  .write(o0)

render(o0)
