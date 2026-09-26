search synth

noise(seed: 1, ridges: true)
  .write(o0)

cellularAutomata(ruleIndex: seeds, tex: read(o0))
  .write(o1)

render(o1)
