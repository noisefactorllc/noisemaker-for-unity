search synth

noise(seed: 1, ridges: true)
  .write(o0)

mnca(n1v1: 50, tex: read(o0))
  .write(o1)

render(o1)
