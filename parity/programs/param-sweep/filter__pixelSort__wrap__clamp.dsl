search filter, synth

noise(seed: 1, ridges: true)
  .pixelSort(wrap: clamp)
  .write(o0)

render(o0)
