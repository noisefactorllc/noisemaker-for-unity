search synth3d, render

noise3d(scale: 4)
  .renderCubemap3d(threshold: 0.5, filtering: 0)
  .write(o0)

render(o0)