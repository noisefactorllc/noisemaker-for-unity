search points, synth, render

perlin()
  .pointsEmit()
  .physical()
  .pointsRender(inputIntensity: 50)
  .write(o0)

render(o0)
