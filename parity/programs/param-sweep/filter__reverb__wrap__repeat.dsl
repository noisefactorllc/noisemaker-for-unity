search filter, synth

noise(seed: 1, ridges: true)
  .reverb(wrap: repeat)
  .write(o0)

render(o0)
