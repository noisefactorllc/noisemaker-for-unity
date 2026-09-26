search synth3d, filter3d, render

noise3d(volumeSize: x32)
  .flow3d(behavior: crosshatch)
  .render3d()
  .write(o0)

render(o0)
