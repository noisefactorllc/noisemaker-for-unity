search filter, synth

noise(seed: 1, ridges: true)
  .halftone(pattern: circle, mode: mono)
  .write(o0)

render(o0)
