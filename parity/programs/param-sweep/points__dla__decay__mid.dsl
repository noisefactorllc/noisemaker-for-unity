search points, synth, render

perlin()
  .pointsEmit()
  .dla(decay: 0.5)
  .pointsRender()
  .write(o0)

render(o0)
