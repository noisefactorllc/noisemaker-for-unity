search points, synth, render

perlin()
  .pointsEmit()
  .physical()
  .pointsRender(intensity: 50)
  .write(o0)

render(o0)
