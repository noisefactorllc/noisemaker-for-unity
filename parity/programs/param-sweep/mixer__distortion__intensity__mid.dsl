search mixer, synth

cell()
.write(o0)

noise(ridges: true)
.distortion(intensity: 100, tex: read(o0))
.write(o1)
