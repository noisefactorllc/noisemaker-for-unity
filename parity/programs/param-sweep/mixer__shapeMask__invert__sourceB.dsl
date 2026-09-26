search mixer, synth

noise(ridges: true, colorMode: mono)
.write(o0)

noise(ridges: true)
.shapeMask(invert: sourceB, tex: read(o0))
.write(o1)
