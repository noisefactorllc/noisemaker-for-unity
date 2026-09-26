search points, synth, render

perlin()
  .pointsEmit()
  .life(attractionScale: 2.5)
  .pointsRender()
  .write(o0)

render(o0)
