search points, synth, render

perlin()
  .pointsEmit()
  .flow(behavior: randomMix)
  .pointsRender()
  .write(o0)

render(o0)
