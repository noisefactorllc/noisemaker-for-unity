search points, synth, render

perlin()
  .pointsEmit()
  .physical(wander: 0.5)
  .pointsRender()
  .write(o0)

render(o0)
