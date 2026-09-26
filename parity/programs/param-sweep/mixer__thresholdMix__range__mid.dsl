search mixer, synth

noise()
.write(o0)

solid(color: #000000)
.thresholdMix(range: 0.5, tex: read(o0))
.write(o1)
