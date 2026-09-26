search points, synth, render

perlin()
  .pointsEmit()
  .physical()
  .pointsRender(fieldOfView: 80)
  .write(o0)

render(o0)
