search mixer, synth

cell()
.write(o0)

noise(ridges: true)
.distortion(mode: reflect, tex: read(o0))
.write(o1)
