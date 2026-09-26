search synth3d, filter3d, render

noise3d(volumeSize: x32)
  .flow3d(lifetime: 60)
  .render3d()
  .write(o0)

render(o0)
