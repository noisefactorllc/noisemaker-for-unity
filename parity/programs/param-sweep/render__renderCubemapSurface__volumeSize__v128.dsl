search synth3d, filter3d, render

noise3d(volumeSize: x64)
  .renderCubemapSurface(volumeSize: v128)
  .write(o0)

render(o0)
