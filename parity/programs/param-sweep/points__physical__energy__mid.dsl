search points, synth, render

perlin()
  .pointsEmit()
  .physical(energy: 1)
  .pointsRender()
  .write(o0)

render(o0)
