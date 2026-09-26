search filter, synth

noise(seed: 1, ridges: true)
  .edge(size: kernel7x7)
  .write(o0)

render(o0)
