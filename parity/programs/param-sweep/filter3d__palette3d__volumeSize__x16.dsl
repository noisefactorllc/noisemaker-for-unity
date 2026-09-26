search synth3d, filter3d, render

noise3d(volumeSize: x64)
  .palette3d(volumeSize: x16)
  .render3d()
  .write(o0)

render(o0)
