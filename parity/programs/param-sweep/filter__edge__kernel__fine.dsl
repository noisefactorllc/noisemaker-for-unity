search filter, synth

noise(seed: 1, ridges: true)
  .edge(kernel: fine)
  .write(o0)

render(o0)
