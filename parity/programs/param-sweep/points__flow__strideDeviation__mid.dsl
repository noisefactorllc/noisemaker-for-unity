search points, synth, render

perlin()
  .pointsEmit()
  .flow(strideDeviation: 0.25)
  .pointsRender()
  .write(o0)

render(o0)
