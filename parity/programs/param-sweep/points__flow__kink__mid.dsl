search points, synth, render

perlin()
  .pointsEmit()
  .flow(kink: 5)
  .pointsRender()
  .write(o0)

render(o0)
