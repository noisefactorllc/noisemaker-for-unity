search synth3d, filter3d, render

noise3d(volumeSize: x32)
  .flow3d(density: 50.5)
  .render3d()
  .write(o0)

render(o0)
