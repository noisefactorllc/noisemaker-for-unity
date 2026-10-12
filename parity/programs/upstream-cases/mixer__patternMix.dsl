search synth, mixer

noise(seed: 1, ridges: true, colorMode: mono).write(o0)
noise(seed: 2, ridges: true).patternMix(tex: o0).write(o1)
render(o1)