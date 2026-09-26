search synth, filter, render

noise(ridges: true)
  .loopBegin(alpha: 95, intensity: 50)
  .warp()
  .loopEnd()
  .write(o0)

render(o0)
