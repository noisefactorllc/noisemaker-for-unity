search mixer, synth

noise(ridges: true, colorMode: mono)
.write(o0)

noise(ridges: true)
.shapeMask(speed: 2, tex: read(o0))
.write(o1)
