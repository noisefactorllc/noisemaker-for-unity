search synth

noise(seed: 1, ridges: true)
  .write(o0)

reactionDiffusion(smoothing: bSpline3x3, tex: read(o0))
  .write(o1)

render(o1)
