search synth3d, filter3d, render

noise3d(volumeSize: x32)
  .flow3d(intensity: 50)
  .render3d()
  .write(o0)

render(o0)
