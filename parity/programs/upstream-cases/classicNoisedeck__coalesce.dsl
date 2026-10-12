search synth, classicNoisedeck

noise(seed: 1, speed: 0).write(o1)
noise(seed: 7, speed: 0).write(o2)
read(o1).coalesce(tex: read(o2), blendMode: cloak, mix: 60, refractAAmt: 40, refractBAmt: 40).coalesce(tex: read(o2), mix: 0, refractAAmt: 40, refractADir: 30, refractBAmt: 20, refractBDir: -45).write(o0)
render(o0)