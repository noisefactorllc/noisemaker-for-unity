// viewer-port.mjs — open a BrowserSession whose viewer server port survives
// restricted runners.
//
// The harness's viewer server is transport, not part of the capture, but the
// port choice decides whether the render starts at all:
//   * a pinned SHADE_VIEWER_PORT gives the harness a single candidate, so a
//     busy port aborts the render (listen EADDRINUSE), and
//   * an ephemeral listen(0) fails with EPERM in runners that permit only
//     explicit loopback ports (43117-43126).
// openViewerSession() therefore tries candidates in turn, keeping the caller's
// pinned port first, then the harness's own chain (unset env: NM_TS_PORT,
// ephemeral, fixed fallbacks), then each permitted fixed port. The request
// handling and capture are identical for every port.
export async function openViewerSession({ harness, backend, env = process.env, ports = ['43117', '43118', '43119', '43120', '43121', '43122', '43123', '43124', '43125', '43126'] }) {
  const { BrowserSession } = harness
  const candidates = []
  if (env.SHADE_VIEWER_PORT) candidates.push(env.SHADE_VIEWER_PORT)
  candidates.push(null, ...ports)
  let lastListenError = null
  for (const viewerPort of candidates) {
    if (viewerPort === null) delete env.SHADE_VIEWER_PORT
    else env.SHADE_VIEWER_PORT = viewerPort
    const session = new BrowserSession({ backend })
    try {
      await session.setup()
      return session
    } catch (err) {
      if (!/listen (EADDRINUSE|EPERM)/.test(String(err?.message ?? err))) throw err
      lastListenError = err
      await session.teardown()
    }
  }
  throw lastListenError ?? new Error('no permitted viewer port for the parity viewer server')
}
