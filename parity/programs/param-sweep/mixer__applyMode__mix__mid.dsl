search mixer, synth

noise(seed: 1, ridges: true)
.write(o0)

perlin()
.applyMode(mix: 100, tex: read(o0))
.write(o1)
