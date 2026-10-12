search synth, synth3d, render
heightmap3d(heightTex: testPattern(pattern: gradient), tex: testPattern(pattern: colorBars), volumeSize: x32, heightScale: 0.6, baseHeight: 0.1).renderLandscape3d(filtering: isosurface, viewMode: perspective, rotateX: 0.62, rotateY: 0.5, posY: 12).write(o0)
render(o0)