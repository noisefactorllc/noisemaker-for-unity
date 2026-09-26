search synth3d, filter3d, render

noise3d(volumeSize: x64)
  .render3d(filtering: voxel)
  .write(o0)

render(o0)
