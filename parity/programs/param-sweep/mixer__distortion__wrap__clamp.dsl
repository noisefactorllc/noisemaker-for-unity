search mixer, synth

cell()
.write(o0)

noise(ridges: true)
.distortion(wrap: clamp, tex: read(o0))
.write(o1)
