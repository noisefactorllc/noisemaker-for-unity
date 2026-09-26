search mixer, synth

noise(ridges: true, colorMode: mono)
.write(o0)

noise(ridges: true)
.shapeMask(radius: 0.5, tex: read(o0))
.write(o1)
