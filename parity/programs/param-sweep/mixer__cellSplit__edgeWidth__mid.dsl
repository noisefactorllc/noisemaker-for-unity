search mixer, synth

solid(color: #000000)
.write(o0)

noise()
.cellSplit(edgeWidth: 0.1, invert: sourceB)
.write(o1)
