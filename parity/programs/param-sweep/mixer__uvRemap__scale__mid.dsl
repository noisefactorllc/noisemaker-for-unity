search mixer, synth

pattern()
.write(o0)

noise(ridges: true)
.uvRemap(tex: read(o0), scale: 200)
.write(o1)
