#!/usr/bin/env node
// param-sweep.mjs — generate per-effect parameter-variant DSL programs for the
// graph-parity sweep (GAP-001 parameter/state breadth).
//
// For every ported effect with a curated default program in --selftest/, this
// script reads the effect definition from the pinned reference repo, enumerates
// its user-facing parameters (globals with a `ui` descriptor), and emits one DSL
// variant per non-default value class:
//   - dropdown/choice params: one variant per non-default choice (structural)
//   - boolean params: the flipped value
//   - float/int sliders: the midpoint of [min, max] (or an endpoint when the
//     midpoint equals the default); for unbounded params (no min/max) the
//     default+1 is emitted (slug `plus1`) — a declared variant-class choice;
//     the gate is fail-closed, so any value outside a parameter's legal range
//     surfaces as a compile failure on one or both sides, never a silent pass
//   - seed-like params are covered by the slider rule
// Params of type color / surface / string and controls button/vector3 are
// recorded as exclusions (counted in the manifest, not emitted).
//
// Usage: node param-sweep.mjs <outDir>
//   writes <outDir>/<ns>__<name>__<param>__<slug>.dsl and
//   <outDir>/manifest.tsv ("<name>\t<dslPath>"), plus <outDir>/exclusions.tsv
//   ("<name>\t<param>\t<reason>").
//
// Env: NM_REFERENCE_ROOT — pinned reference repo (default: ../../noisemaker).

import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs'
import { join, resolve, basename } from 'node:path'
import { pathToFileURL } from 'node:url'

const outDir = process.argv[2]
if (!outDir) { process.stderr.write('usage: node param-sweep.mjs <outDir>\n'); process.exit(2) }

const REFERENCE_ROOT = process.env.NM_REFERENCE_ROOT
  ? resolve(process.env.NM_REFERENCE_ROOT)
  : resolve(process.cwd(), '..', 'noisemaker')
const MANIFEST = join(REFERENCE_ROOT, 'shaders', 'effects', 'manifest.json')
const BASE_DIR = resolve(process.cwd(), '--selftest')

const UNPORTED = new Set(['synth/media', 'synth/scope', 'synth/spectrum'])
const manifest = JSON.parse(readFileSync(MANIFEST, 'utf8'))
const effectIds = Object.keys(manifest).filter((id) => !UNPORTED.has(id)).sort()

const SKIP_CONTROLS = new Set(['button', 'vector3'])
// Bare identifiers that the reference resolves as state-value AST nodes, never
// as choice values (verified against the oracle: `geometry: seed` emits an
// `_ast` state reference, not the choice number).
const STATE_VALUE_NAMES = new Set(['time','frame','mouse','resolution','seed','a','u1','u2','u3','u4','s1','s2','b1','b2','a1','a2','deltaTime'])
const SKIP_TYPES = new Set(['color', 'surface', 'string'])

function fmtNum (v) {
  if (Number.isInteger(v)) return String(v)
  const r = Math.round(v * 1e6) / 1e6
  return String(r)
}

function pickValue (param, name) {
  const t = param.type
    if (param.choices) {
    const entries = Object.entries(param.choices).filter(([k, v]) => v !== param.default
      && /^[A-Za-z_][A-Za-z0-9_]*$/.test(k) && !STATE_VALUE_NAMES.has(k))
    if (entries.length === 0) return 'choices not DSL-expressible (state-value or non-identifier keys)'
    return entries.map(([k]) => ({ kind: 'choice', value: k, slug: k }))
  }
  if (t === 'boolean') return [{ kind: 'bool', value: !param.default, slug: param.default ? 'false' : 'true' }]
  if (t === 'float' || t === 'int') {
    if (typeof param.min === 'number' && typeof param.max === 'number' && param.max > param.min) {
      const mid = t === 'int' ? Math.round((param.min + param.max) / 2) : (param.min + param.max) / 2
      const val = (Math.abs(mid - param.default) < 1e-9) ? param.max : mid
      return [{ kind: 'num', value: fmtNum(val), slug: 'mid' }]
    }
    const val = (param.default ?? 0) + 1
    return [{ kind: 'num', value: fmtNum(val), slug: 'plus1' }]
  }
  return null
}

// Insert or patch `param: value` inside the first call site of `func(`.
function applyParam (dsl, func, param, value) {
  const re = new RegExp(`(^|\\n)[ \\t]*(\\.)?${func}\\(`)
  const m = dsl.match(re)
  if (!m) return null
  const at = m.index + m[0].length - 1 // at the '('
  // find matching close paren (no nesting expected in these programs)
  let depth = 0, end = -1
  for (let i = at; i < dsl.length; i++) {
    if (dsl[i] === '(') depth++
    else if (dsl[i] === ')') { depth--; if (depth === 0) { end = i; break } }
  }
  if (end < 0) return null
  const call = dsl.slice(at + 1, end)
  const arg = `${param}: ${value}`
  const patchRe = new RegExp(`\\b${param}\\s*:\\s*[^,)]+`)
  let inner
  if (patchRe.test(call)) inner = call.replace(patchRe, arg)
  else inner = call.trim().length === 0 ? arg : call.replace(/^(\s*)/, `$1${arg}, `)
  return dsl.slice(0, at + 1) + inner + dsl.slice(end)
}

mkdirSync(outDir, { recursive: true })
const tsv = []
const exclusions = []
let ok = 0, nobase = 0, genfail = 0

for (const id of effectIds) {
  const [ns, name] = id.split('/')
  const base = join(BASE_DIR, `${ns}__${name}.dsl`)
  if (!existsSync(base)) { nobase++; exclusions.push(`${id}\t-\tno base program`); continue }
  const baseDsl = readFileSync(base, 'utf8')
  let def
  try {
    def = (await import(pathToFileURL(join(REFERENCE_ROOT, 'shaders', 'effects', ns, name, 'definition.js')))).default
  } catch (e) {
    exclusions.push(`${id}\t-\tdefinition import failed: ${e.message}`)
    continue
  }
  const globals = def.globals || {}
  for (const [param, p] of Object.entries(globals)) {
    if (!p || !p.ui || SKIP_CONTROLS.has(p.ui.control)) { continue }
    if (SKIP_TYPES.has(p.type)) { exclusions.push(`${id}\t${param}\ttype ${p.type} not swept`); continue }
    const picks = pickValue(p, param)
    if (typeof picks === 'string') { exclusions.push(`${id}\t${param}\t${picks}`); continue }
    if (!picks) { exclusions.push(`${id}\t${param}\tno enumerable values`); continue }
    for (const pk of picks) {
      const dsl = applyParam(baseDsl, def.func, param, pk.value)
      if (dsl == null) { genfail++; exclusions.push(`${id}\t${param}\tcall site not found`); continue }
      const fname = `${ns}__${name}__${param}__${pk.slug}.dsl`
      writeFileSync(join(outDir, fname), dsl.endsWith('\n') ? dsl : dsl + '\n')
      tsv.push(`${ns}__${name}__${param}__${pk.slug}\t${fname}`)
      ok++
    }
  }
}

writeFileSync(join(outDir, 'manifest.tsv'), tsv.join('\n') + (tsv.length ? '\n' : ''))
writeFileSync(join(outDir, 'exclusions.tsv'), exclusions.join('\n') + (exclusions.length ? '\n' : ''))
process.stdout.write(`emitted ${ok} variants; ${nobase} effects without base program; ${genfail} emit failures; ${exclusions.length} exclusions\n`)
