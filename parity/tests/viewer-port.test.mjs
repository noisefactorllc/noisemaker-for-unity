import test from 'node:test'
import assert from 'node:assert/strict'
import { openViewerSession } from '../viewer-port.mjs'

// Negative control for the viewer-port fallback: a held or blocked port makes
// the harness's listen fail (EADDRINUSE when another process holds the port,
// EPERM where a runner permits only explicit loopback ports); both exercise
// the same retry path, and the capture is identical on every port.

function fakeHarness(attempts) {
  const seen = []
  class BrowserSession {
    constructor({ backend }) { this.backend = backend }
    async setup() {
      seen.push(process.env.SHADE_VIEWER_PORT ?? null)
      const failure = attempts[seen.length - 1]
      if (failure) {
        const err = new Error(`listen ${failure}: address problem 127.0.0.1`)
        err.code = failure
        throw err
      }
      this.page = {}
    }
    async teardown() { this.toreDown = true }
  }
  return { BrowserSession, seen }
}

test('openViewerSession keeps the caller-pinned port first, then falls through', async () => {
  const harness = fakeHarness(['EADDRINUSE', 'EADDRINUSE'])
  process.env.SHADE_VIEWER_PORT = '43120'
  try {
    const session = await openViewerSession({ harness, backend: 'webgl2' })
    assert.equal(session.backend, 'webgl2')
    assert.deepEqual(harness.seen, ['43120', null, '43117'])
  } finally {
    delete process.env.SHADE_VIEWER_PORT
  }
})

test('openViewerSession rethrows failures that are not listener errors', async () => {
  const harness = fakeHarness(['EACCES'])
  await assert.rejects(
    () => openViewerSession({ harness, backend: 'webgl2' }),
    /EACCES/,
  )
})

test('openViewerSession rejects after every candidate fails', async () => {
  const harness = fakeHarness(Array(11).fill('EPERM'))
  await assert.rejects(
    () => openViewerSession({ harness, backend: 'webgl2' }),
    /listen EPERM/,
  )
  assert.equal(harness.seen.length, 11)
})
