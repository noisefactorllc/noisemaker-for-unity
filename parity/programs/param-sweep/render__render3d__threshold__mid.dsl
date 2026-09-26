search synth3d, filter3d, render

noise3d(volumeSize: x64)
  .render3d(threshold: 1)
  .write(o0)

render(o0)
