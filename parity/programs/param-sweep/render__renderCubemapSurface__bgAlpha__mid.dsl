search synth3d, filter3d, render

noise3d(volumeSize: x64)
  .renderCubemapSurface(bgAlpha: 0.5)
  .write(o0)

render(o0)
