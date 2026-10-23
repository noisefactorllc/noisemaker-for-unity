import test from 'node:test'
import assert from 'node:assert/strict'
import { inflateSync } from 'node:zlib'
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { renderOne, prepareReferencePage } from '../batch-golden.mjs'

function fakePage (backendName = 'webgpu') {
  const calls = []
  const backend = {
    getName: () => backendName,
    textures: new Map(),
    device: { queue: { onSubmittedWorkDone: async () => calls.push('settled') } },
    readPixels: async id => {
      calls.push(id)
      return { width: 1, height: 2, data: Uint8Array.from([1, 2, 3, 255, 4, 5, 6, 255]) }
    }
  }
  globalThis.window = {
    __noisemakerRenderingPipeline: {
      backend, graph: { id: 'compiled', renderSurface: 'o2' },
      surfaces: new Map([['o2', { read: 'actual-output' }]]), render: () => {},
      initAsyncEffects: () => {}, checkAsyncRegen: () => {},
      whenAsyncInitsSettled: async () => {}
    }
  }
  globalThis.document = { getElementById: () => ({ dispatchEvent () {}, click () {} }) }
  const page = {
    evaluate: async (fn, arg) => fn(arg),
    waitForFunction: async () => {},
    reload: async () => calls.push('reload'),
    setViewportSize: async () => calls.push('viewport')
  }
  return { page, calls }
}

function pngRows (png) {
  let offset = 8
  while (offset < png.length) {
    const length = png.readUInt32BE(offset)
    if (png.toString('ascii', offset + 4, offset + 8) === 'IDAT') {
      return [...inflateSync(png.subarray(offset + 8, offset + 8 + length))]
    }
    offset += length + 12
  }
  throw new Error('missing IDAT')
}

test('WebGPU captures the actual render surface and normalizes Unity row order', async () => {
  const { page, calls } = fakePage()
  const result = await renderOne(page, 'shape()', 1, 0.25, 'old', 8, 0, null, null, null, 'webgpu')
  assert.deepEqual(calls, ['settled', 'actual-output'])
  assert.deepEqual(pngRows(result.png), [0, 4, 5, 6, 255, 0, 1, 2, 3, 255])
})

test('a fallback backend cannot be labeled as a WebGPU golden', async () => {
  const { page } = fakePage('webgl2')
  await assert.rejects(renderOne(page, 'shape()', 1, 0.25, 'old', 8, 0, null, null, null, 'webgpu'), /requested webgpu.*active webgl2/)
})

test('backend is selected again after page reload', async () => {
  const { page, calls } = fakePage()
  const session = { page, setBackend: async name => calls.push(name) }
  await prepareReferencePage(session, { backend: 'webgpu', size: 256 }, true)
  assert.deepEqual(calls, ['reload', 'webgpu', 'viewport'])
})

test('WebGPU raw velocity requests fail instead of reporting a successful golden', async () => {
  const { page } = fakePage()
  await assert.rejects(renderOne(page, 'shape()', 1, 0.25, 'old', 8, 0, 'velocity', null, null, 'webgpu'), /velocity.*WebGL2/)
})


test('CLI exits nonzero when a manifest item cannot be rendered', () => {
  const root = mkdtempSync(join(tmpdir(), 'unity-golden-test-'))
  try {
    const harness = join(root, 'vendor', 'shade-mcp', 'harness')
    mkdirSync(harness, { recursive: true })
    writeFileSync(join(root, 'package.json'), '{"type":"module"}')
    writeFileSync(join(harness, 'index.js'), `export class BrowserSession {
      page = { waitForFunction: async () => {}, setViewportSize: async () => {}, evaluate: async () => null };
      async setup () {} async setBackend () {} async teardown () {}
    }`)
    const manifest = join(root, 'manifest.tsv')
    writeFileSync(manifest, 'missing\t' + join(root, 'missing.dsl') + '\n')
    const result = spawnSync(process.execPath, [fileURLToPath(new URL('../batch-golden.mjs', import.meta.url)), manifest, join(root, 'output')], {
      env: { ...process.env, NM_REFERENCE_ROOT: root }, encoding: 'utf8'
    })
    assert.equal(result.status, 1, result.stdout + result.stderr)
    assert.match(result.stdout, /0 ok, 1 fail/)
    assert.match(result.stderr, /GOLDEN-FAIL.*ENOENT/)
  } finally { rmSync(root, { recursive: true, force: true }) }
})

test('texture fixtures upload raw texels after clear and are checked after the frames', async () => {
  const { page } = fakePage('webgl2')
  const events = []
  const pipeline = window.__noisemakerRenderingPipeline
  const texture = { effect: 'synth/media', uniform: 'imageTex', width: 1, height: 2, data: [1, 2, 3, 4, 5, 6, 7, 8] }
  const pass = { id: 'node_0_pass_0', effectNamespace: 'synth', effectFunc: 'media', effectKey: 'synth.media', inputs: { imageTex: 'imageTex_step_0' }, uniforms: { imageSize: [1024, 1024], scaleAmt: 50 } }
  const compiled = [{ id: 'node_0_pass_0', uniforms: { imageSize: [64, 64], scaleAmt: 100 } }]
  pipeline.graph.passes = [pass]
  window.__noisemakerRegistry = {
    getEffect: name => name === 'synth/media'
      ? { globals: { imageSize: { uniform: 'imageSize', ui: { control: false } }, scaleAmt: { uniform: 'scaleAmt', ui: { control: 'slider' } } } }
      : undefined
  }
  pipeline.backend.textures.set('stale', {})
  pipeline.backend.clearTexture = id => events.push(['clear', id])
  pipeline.render = () => events.push(['render'])
  let stored = null
  pipeline.backend.readPixels = id => {
    events.push(['read', id])
    // WebGL2 readPixels is top-down: data row 1 first.
    return { width: 1, height: 2, data: Uint8Array.from([...stored.slice(4), ...stored.slice(0, 4)]) }
  }
  globalThis.ImageData = class { constructor (data, width, height) { Object.assign(this, { data, width, height }) } }
  globalThis.createImageBitmap = async (image, options) => ({ image, options })
  window.__noisemakerCanvasRenderer = {
    updateTextureFromSource: (id, bitmap, options) => {
      events.push(['upload', id, options.flipY, bitmap.options.premultiplyAlpha])
      stored = Array.from(bitmap.image.data)
      return { width: bitmap.image.width, height: bitmap.image.height }
    }
  }
  try {
    // The fake page has no GL output surface, so a WebGL2 render ends at the
    // output readback, after the fixture steps.
    await assert.rejects(renderOne(page, 'media()', 1, 0.25, 'old', 1, 0, null, null, null, 'webgl2', [texture], compiled),
      /readback: no GL surface/)
    assert.deepEqual(events, [
      ['clear', 'stale'], ['upload', 'imageTex_step_0', false, 'none'], ['render'], ['read', 'imageTex_step_0']
    ])
    // The hidden imageSize returns to the compiled DSL value; visible params keep theirs.
    assert.deepEqual(pass.uniforms, { imageSize: [64, 64], scaleAmt: 50 })
    stored = [9, 9, 9, 9, 5, 6, 7, 8]
    window.__noisemakerCanvasRenderer.updateTextureFromSource = () => ({ width: 1, height: 2 })
    await assert.rejects(renderOne(page, 'media()', 1, 0.25, 'old', 1, 0, null, null, null, 'webgl2', [texture], compiled),
      /texels differ after rendering: imageTex_step_0/)
    pipeline.graph.passes = []
    await assert.rejects(renderOne(page, 'media()', 1, 0.25, 'old', 1, 0, null, null, null, 'webgl2', [texture], compiled),
      /no executing effect: synth\/media/)
  } finally {
    delete globalThis.ImageData
    delete globalThis.createImageBitmap
    delete window.__noisemakerCanvasRenderer
    delete window.__noisemakerRegistry
  }
})

test('CPU overlays restart after clear and settle before frame zero', async () => {
  const { page } = fakePage()
  const events = []
  const pipeline = window.__noisemakerRenderingPipeline
  const uniforms = { density: 0.8, seed: 2 }
  pipeline.graph.passes = [{ nodeId: 'overlay-node', effectKey: 'filter.fibers', uniforms }]
  pipeline.backend.textures.set('overlay-texture', {})
  pipeline.backend.clearTexture = id => events.push(['clear', id])
  pipeline.initAsyncEffects = () => events.push(['init'])
  pipeline.checkAsyncRegen = (...args) => events.push(['regen', ...args])
  let ready = false
  pipeline.whenAsyncInitsSettled = async () => {
    await Promise.resolve()
    ready = true
    events.push(['ready'])
  }
  pipeline.render = () => {
    assert.equal(ready, true, 'frame rendered before overlay upload')
    events.push(['render'])
  }
  await renderOne(page, 'shape()', 1, 0.25, 'old', 1, 0, null, null, null, 'webgpu')
  assert.deepEqual(events, [
    ['clear', 'overlay-texture'], ['init'],
    ['regen', 'overlay-node', 'filter.fibers', uniforms], ['ready'], ['render']
  ])
})
