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
      surfaces: new Map([['o2', { read: 'actual-output' }]]), render: () => {}
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
