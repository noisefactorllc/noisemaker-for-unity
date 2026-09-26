search mixer, synth

cell()
.write(o0)

noise(ridges: true)
.distortion(antialias: true, tex: read(o0))
.write(o1)
