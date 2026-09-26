search mixer, synth

cell()
.write(o0)

noise(ridges: true)
.distortion(smoothing: 50.5, tex: read(o0))
.write(o1)
