search points, synth, render

perlin()
  .pointsEmit()
  .flow(quantize: true)
  .pointsRender()
  .write(o0)

render(o0)
