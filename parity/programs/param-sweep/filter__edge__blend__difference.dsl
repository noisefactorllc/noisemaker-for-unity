search filter, synth

noise(seed: 1, ridges: true)
  .edge(blend: difference)
  .write(o0)

render(o0)
