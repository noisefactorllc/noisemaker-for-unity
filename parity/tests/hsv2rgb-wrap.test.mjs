// Source-bound contract test for the hsv2rgb hue-sector wrap that noisemaker
// 6f98d26a applied upstream and this port carries in classicNoisedeck
// HLSL effects. Each function's last hue sector must be an unconditional else
// assigning (c, 0, x): at h = 1.0, which frac() can produce for a hue just
// below a whole number, x is 0 and the colour is that of h = 0.0, so the hue
// wraps instead of rendering black. The test parses the chains out of the
// candidate sources, simulates them in double precision, and, when
// NM_REFERENCE_ROOT points at a noisemaker checkout, requires the same chain
// and the same rgb output from the pinned upstream GLSL for every probe hue.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

// [HLSL file, upstream GLSL dir]
const CASES = [
  ['BitEffects', 'bitEffects'],
  ['Caustic', 'caustic'],
  ['CellNoise', 'cellNoise'],
  ['Effects', 'effects'],
  ['Fractal', 'fractal'],
  ['Moodscape', 'moodscape'],
  ['Shapes', 'shapes'],
  ['Shapes3d', 'shapes3d'],
];

const HLSL_BASE = 'unity/com.noisemaker.hlsl/Shaders/Effects/classicNoisedeck';
const GLSL_BASE = 'shaders/effects/classicNoisedeck';

// Collect every rgb assignment in the function together with the condition
// guarding it: null for the final else, else the condition text. The one-line
// and brace-on-next-line layouts collapse to the same shape because the scan
// only looks at the text between assignments.
function extractChain(source) {
  const def = source.match(/(?:float3|vec3)\s+\w*hsv2rgb\s*\(/);
  assert.ok(def, 'missing hsv2rgb definition');
  const start = def.index;
  const body = source.slice(start, source.indexOf('\n}\n', start) + 3)
    .split('\n')
    // Comment lines hold no executable guard or sector.
    .filter((line) => !line.trim().startsWith('//'))
    .join('\n')
    // Drop an `float3 rgb = float3(0,0,0)` declaration: not a sector.
    .replace(/(?:float3|vec3(?:<f32>)?)\s+rgb\s*=\s*(?:float3|vec3(?:<f32>)?)\([^)]*\)\s*;/, '');
  const parts = body.split(/rgb\s*=\s*/);
  const chain = [];
  for (let i = 1; i < parts.length; i++) {
    const part = parts[i];
    const head = part.slice(0, part.indexOf(';', part.indexOf(')') + 1));
    const vec = head.match(/(?:float3|vec3(?:<f32>)?)\(([^)]*)\)/);
    assert.ok(vec, `no rgb vector in chain: ${head}`);
    // The guard text sits between the previous statement's end and this
    // assignment: it holds no semicolons, so it starts after the last one.
    // Strip trailing braces and whitespace, then read the guard with string
    // ops (no regex anchors).
    let tail = parts[i - 1].slice(parts[i - 1].lastIndexOf(';') + 1).trim();
    while (tail.endsWith('{') || tail.endsWith('}')) {
      tail = tail.slice(0, -1).trim();
    }
    while (tail.startsWith('{') || tail.startsWith('}')) {
      tail = tail.slice(1).trim();
    }
    let cond = null;
    if (tail !== 'else') {
      assert.ok(tail.endsWith(')'), `no if guard before sector: ${tail}`);
      const open = tail.lastIndexOf('(');
      const head = tail.slice(0, open).trim();
      assert.ok(head === 'if' || head === 'else if', `no if guard before sector: ${tail}`);
      cond = tail.slice(open + 1, -1).replace(/\s+/g, ' ').trim();
    }
    chain.push({
      cond,
      vec: vec[1].split(',').map((v) => v.trim()),
    });
  }
  return chain;
}

// [low, high) hue interval of one sector, from its condition text. The port
// writes the low bound as `X <= h` or `h >= X`, the high bound as `h < Y`.
function sectorOf(cond) {
  if (cond === null) return [5 / 6, Infinity];
  const c = cond.replace(/\s+/g, '');
  const low = c.match(/(\d+\.0)\/6\.0<=h/) || c.match(/h>=(\d+\.0)\/6\.0/);
  const zeroLow = c.includes('0.0<=h') || c.includes('h>=0.0');
  const sixthHigh = c.match(/h<(\d+\.0)\/6\.0/);
  const oneHigh = c.includes('h<1.0');
  assert.ok(low || zeroLow, `unparsed low bound: ${cond}`);
  assert.ok(sixthHigh || oneHigh, `unparsed high bound: ${cond}`);
  return [
    low ? Number(low[1]) / 6 : 0,
    sixthHigh ? Number(sixthHigh[1]) / 6 : 1,
  ];
}

function simulate(chain, h, s, v) {
  const c = v * s;
  const h6 = h * 6;
  const x = c * (1 - Math.abs((h6 - 2 * Math.floor(h6 / 2)) - 1));
  const m = v - c;
  const term = { c, x, '0.0': 0 };
  for (const step of chain) {
    const [low, high] = sectorOf(step.cond);
    if (h >= low && h < high) {
      return step.vec.map((t) => term[t] + m);
    }
  }
  return null;
}

const S = 0.75;
const V = 0.8;
// Sector boundaries, the largest float32 below 1 (the GLSL highp bound),
// exactly 1.0 (the wrapped case), and the tiny negative hues upstream
// measured: frac maps them just below 1.0.
const PROBES = [0, 1 / 6, 2 / 6, 3 / 6, 4 / 6, 5 / 6, 1 - 2 ** -24, 1.0, -1.49e-8, -2.61e-8];

// The classic hsv2rgb sector order, as rgb offsets from the m term.
const CANONICAL = [
  ['c', 'x', '0.0'],
  ['x', 'c', '0.0'],
  ['0.0', 'c', 'x'],
  ['0.0', 'x', 'c'],
  ['x', '0.0', 'c'],
  ['c', '0.0', 'x'],
].map((vec, i) => ({
  cond: i < 5 ? `${i}.0/6.0 <= h && h < ${i + 1}.0/6.0` : null,
  vec,
}));

test('changed classicNoisedeck hsv2rgb helpers wrap the last hue sector', () => {
  for (const [hlsl] of CASES) {
    const chain = extractChain(
      readFileSync(join(ROOT, HLSL_BASE, `${hlsl}.hlsl`), 'utf8'),
    );
    assert.equal(chain.length, 6, `${hlsl}: expected 6 hue sectors`);
    const last = chain[5];
    assert.equal(last.cond, null, `${hlsl}: last sector must be an unconditional else`);
    assert.deepEqual(last.vec, ['c', '0.0', 'x'], `${hlsl}: last sector must be (c, 0, x)`);
    chain.slice(0, 5).forEach((step, i) => {
      assert.deepEqual(step.vec, CANONICAL[i].vec, `${hlsl}: sector ${i} changed colour order`);
      assert.notEqual(step.cond, null, `${hlsl}: sector ${i} lost its condition`);
    });
    // The wrapped contract, evaluated from the parsed chain: every probe hue
    // takes the same sector as the canonical chain, so h = 1.0 renders the
    // h = 0.0 colour instead of black.
    const at = (h) => simulate(chain, h, S, V);
    assert.deepEqual(at(1.0), at(0.0), `${hlsl}: h = 1.0 must render the h = 0.0 colour`);
    assert.deepEqual(at(1.0), simulate(CANONICAL, 0.0, S, V), `${hlsl}: h = 1.0 left the last sector`);
    for (const h of PROBES) {
      const hf = h - Math.floor(h);
      assert.deepEqual(at(hf), simulate(CANONICAL, hf, S, V), `${hlsl}: wrong sector at h = ${h}`);
    }
  }
});

test('port chains match the pinned upstream GLSL chains at every probe hue', () => {
  const ref = process.env.NM_REFERENCE_ROOT;
  if (!ref || !existsSync(join(ref, GLSL_BASE))) {
    return; // Reference-bound leg runs wherever NM_REFERENCE_ROOT is set.
  }
  for (const [hlsl, glsl] of CASES) {
    const port = extractChain(
      readFileSync(join(ROOT, HLSL_BASE, `${hlsl}.hlsl`), 'utf8'),
    );
    const upstream = extractChain(
      readFileSync(join(ref, GLSL_BASE, glsl, 'glsl', `${glsl}.glsl`), 'utf8'),
    );
    assert.equal(upstream.length, 6, `${glsl}.glsl: expected 6 hue sectors`);
    assert.deepEqual(
      upstream.map((s) => [sectorOf(s.cond), s.vec]),
      port.map((s) => [sectorOf(s.cond), s.vec]),
      `${hlsl}: chain differs from ${glsl}.glsl`,
    );
    for (const h of PROBES) {
      const hf = h - Math.floor(h);
      assert.deepEqual(
        simulate(port, hf, S, V),
        simulate(upstream, hf, S, V),
        `${hlsl}: rgb differs from ${glsl}.glsl at h = ${h}`,
      );
    }
  }
});
