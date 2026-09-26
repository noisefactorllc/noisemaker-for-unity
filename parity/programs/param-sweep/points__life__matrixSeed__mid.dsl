search points, synth, render

perlin()
  .pointsEmit()
  .life(matrixSeed: 500)
  .pointsRender()
  .write(o0)

render(o0)
