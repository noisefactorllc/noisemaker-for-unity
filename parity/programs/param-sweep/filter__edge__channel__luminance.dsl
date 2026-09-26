search filter, synth

noise(seed: 1, ridges: true)
  .edge(channel: luminance)
  .write(o0)

render(o0)
