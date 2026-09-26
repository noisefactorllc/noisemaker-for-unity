search mixer, synth

pattern()
.write(o0)

noise(ridges: true)
.uvRemap(mapSource: sourceB, tex: read(o0), scale: 25)
.write(o1)
