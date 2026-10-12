search synth, points, render
testPattern(pattern: gradient).write(o1)
testPattern(pattern: colorBars).write(o2)
solid().pointsEmit(stateSize: x64).heightGrid(heightTex: read(o1), diffuseTex: read(o2), gridScale: 80, heightScale: 25).pointsBillboardRender(viewMode: perspective, rotateX: 0.55, posY: -12, posZ: 10, pointSize: 2, density: 100, intensity: 0, inputIntensity: 0, sizeDistance: 160, brightnessDistance: 200, aperture: 0.5, focalDistance: 80).write(o0)
render(o0)