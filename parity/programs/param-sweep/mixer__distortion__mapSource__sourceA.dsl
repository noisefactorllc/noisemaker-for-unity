search mixer, synth

cell()
.write(o0)

noise(ridges: true)
.distortion(mapSource: sourceA, tex: read(o0))
.write(o1)
