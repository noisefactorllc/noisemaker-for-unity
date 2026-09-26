search synth3d, filter3d, render

noise3d(volumeSize: x64)
  .renderCubemap3d(bgAlpha: 0.5)
  .write(o0)

render(o0)
