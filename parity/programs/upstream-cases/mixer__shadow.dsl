search synth, mixer

noise(seed: 1, scaleX: 100, scaleY: 100).write(o0)
noise(seed: 2, ridges: true, colorMode: mono).shadow(tex: o0).write(o1)
render(o1)