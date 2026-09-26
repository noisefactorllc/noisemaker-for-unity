search synth

noise(seed: 1, ridges: true)
  .write(o0)

subdivide(wrap: repeat, tex: read(o0))
  .write(o1)

render(o1)
