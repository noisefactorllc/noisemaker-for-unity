search mixer, synth

noise()
.write(o0)

solid(color: #000000)
.thresholdMix(thresholdR: 1, mode: rgb, tex: read(o0))
.write(o1)
