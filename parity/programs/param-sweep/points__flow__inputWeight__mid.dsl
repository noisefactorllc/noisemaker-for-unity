search points, synth, render

perlin()
  .pointsEmit()
  .flow(inputWeight: 50)
  .pointsRender()
  .write(o0)

render(o0)
