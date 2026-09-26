search mixer, synth

cell()
.write(o0)

noise(ridges: true)
.distortion(aberration: 12.5, tex: read(o0))
.write(o1)
