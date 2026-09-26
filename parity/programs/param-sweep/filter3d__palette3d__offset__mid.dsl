search synth3d, filter3d, render

noise3d(volumeSize: x64)
  .palette3d(offset: 50)
  .render3d()
  .write(o0)

render(o0)
