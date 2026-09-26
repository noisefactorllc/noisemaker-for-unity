search synth

noise(seed: 1, ridges: true)
  .write(o0)

reactionDiffusion(kill: 57.5, tex: read(o0))
  .write(o1)

render(o1)
