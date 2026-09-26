search mixer, synth

noise(scaleX: 100, scaleY: 100)
.write(o0)

noise(ridges: true, colorMode: mono)
.shadow(spread: 0.5, tex: read(o0))
.write(o1)
