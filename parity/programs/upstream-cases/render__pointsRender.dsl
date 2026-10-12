search synth, points, render
testPattern(pattern: gradient).write(o1)
testPattern(pattern: colorBars).write(o2)
solid().pointsEmit(stateSize: x64).heightGrid(heightTex: read(o1), diffuseTex: read(o2), gridScale: 64, heightScale: 18).pointsRender(viewMode: perspective, rotateX: 0.55, posY: -10, posZ: 12, fieldOfView: 75, density: 100, intensity: 0, inputIntensity: 0, matteOpacity: 0).write(o0)
render(o0)