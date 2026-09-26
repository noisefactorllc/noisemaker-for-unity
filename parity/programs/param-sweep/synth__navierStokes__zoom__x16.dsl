search synth

noise(
  type: hermite,
  ridges: true,
  speed: 30,
  colorMode: mono
)
  .write(o0)

navierStokes(
  zoom: x16, tex: read(o0),
  dyeDecay: 98,
  inputForce: 0.5,
  inputIntensity: 10
)
  .write(o1)

render(o1)
