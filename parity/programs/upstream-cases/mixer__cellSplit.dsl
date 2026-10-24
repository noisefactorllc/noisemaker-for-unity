search synth, mixer
gradient(seed: 2).write(o1)
noise(seed: 1).cellSplit(tex: read(o1), seed: 4).write(o0)
render(o0)