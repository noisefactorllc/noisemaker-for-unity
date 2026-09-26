search mixer, synth

pattern()
.write(o0)

noise(ridges: true)
.uvRemap(offset: 1, tex: read(o0), scale: 25)
.write(o1)
