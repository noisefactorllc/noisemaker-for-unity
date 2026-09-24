# noisemaker-for-unity: completion gaps

Current compatibility matrix: [compatibility report](COMPATIBILITY.md).

## 1. Scope and source revisions

Date: 2026-09-24. Reviewed source: [`d48de74c806213789bf1ed8d79ebd8e918437c57`](https://github.com/noisefactorllc/noisemaker-for-unity/commit/d48de74c806213789bf1ed8d79ebd8e918437c57).
Local HEAD matched remote `main` before checks. The operator requested missing registers for all remaining eligible ports in this run.
This is an initial register with bounded evidence, not a completed port audit or release approval.
No implementation, effect coverage, or parity checkpoint changed. Full audits remain in the existing rotation.

Unity C# and HLSL runtime with a UPM package, Quick Start sample, and Shader Graph wrappers. The README marks development as provisional. [Contract](https://github.com/noisefactorllc/noisemaker-for-unity/blob/d48de74c806213789bf1ed8d79ebd8e918437c57/README.md).

README cites reference v1.0.104 for graph parity and earlier shader snapshots. Those version claims were not resolved to immutable SHAs in this pass.
Current Noisemaker upstream at discovery: `c9ee8a049b2b63cd300da67c01ee40baf29dc288`. Current CPU authority at discovery: `f2eb495d70abcb74e3632e7a652a4f83e4f3b11e`.
These heads identify review targets, not qualification results. No authority evidence was regenerated.

Served kit `0.1.16` identifies source `d48de74c806213789bf1ed8d79ebd8e918437c57`. [Deployment metadata](https://kits.noisedeck.app/unity/0/deployment-meta.json). Inventory and compatibility metadata were retrieved. Artifact bytes and installation were not fully checked.

Only the gap document and README link are publication candidates. Their paths do not trigger the current workflows.
Publication uses a document-only commit on `main`. The containing commit identifies this document's publication revision.
Exact commit, remote document hashes, and downstream results are retained in the shared run record.

## 2. Completion claims

| Claim ID | Claim source | Claimed scope | Finding | Evidence |
|---|---|---|---|---|
| CLAIM-001 | [Source claim](https://github.com/noisefactorllc/noisemaker-for-unity/blob/d48de74c806213789bf1ed8d79ebd8e918437c57/README.md) | Historical 18 of 20 images within one byte, two with separate tolerances, plus 304 of 304 structural graph comparisons. | partial | 27 Python comparator tests passed. A later native batch rendered 19 graphs. Full current-authority parity and player workflows remain unverified. [Local evidence](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-tests-retry.json). |
| CLAIM-002 | [README workflow](https://github.com/noisefactorllc/noisemaker-for-unity/blob/d48de74c806213789bf1ed8d79ebd8e918437c57/README.md) | Human usability: installation, first output, errors, and recovery | unverified | The complete installed workflow was not observed during this register pass. GAP-002. |
| CLAIM-003 | [Official ecosystem documentation](https://docs.unity3d.com/6000.0/Documentation/Manual/upm-ui-local.html) | Ecosystem fit and supported versions | partial | Source entry points were examined. Installed integration and the supported-version matrix remain open. GAP-002. |
| CLAIM-004 | [Distribution description](https://github.com/noisefactorllc/noisemaker-for-unity/blob/d48de74c806213789bf1ed8d79ebd8e918437c57/README.md) | Release readiness | unverified | Metadata and CI alone do not qualify the actual installed artifact. GAP-003. |
| CLAIM-005 | [Exact-source Actions](https://github.com/noisefactorllc/noisemaker-for-unity/actions?query=head_sha%3Ad48de74c806213789bf1ed8d79ebd8e918437c57) | Exact-source automated evidence | supported | [Export kit](https://github.com/noisefactorllc/noisemaker-for-unity/actions/runs/35956581828): `success`. This finding covers workflow status only. |

## 3. Methods and evidence

Environment: macOS 26.5, Darwin arm64. Source-file SHA-256 records bind the local checks to the reviewed revision.
[Source hashes](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/noisemaker-for-unity-source-hashes.json). [Remote evidence](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/noisemaker-for-unity-remote.json).

Executed bounded command:

```sh
python3 -m unittest discover -s parity/tests -p "test_*.py"
```

27 Python comparator tests passed. A later native batch rendered 19 graphs. Full current-authority parity and player workflows remain unverified. Command exit code: 0. [Local evidence](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-tests-retry.json).
Unit and harness checks do not measure rendered parity. No new image denominator or tolerance is inferred from these results.

Official reference: [Unity 6.0 manual, accessed 2026-09-24](https://docs.unity3d.com/6000.0/Documentation/Manual/upm-ui-local.html).
Historical denominators and tolerances remain in the original source documents. Their current-source validity remains an open verification task.

| Developer outcome | This pass | Required remaining check |
|---|---|---|
| Installation | Source instructions and package declarations inspected | Install the actual distribution in an isolated consumer. |
| First useful result | Bounded checks only | Import the local UPM package into an isolated project. Import Quick Start, select Linear color, press Play, and verify a player build. |
| Normal host workflow | Not fully observed | Exercise ordinary parameters, external inputs, resize, state, and cleanup. |
| Error and recovery | Selected tests only where listed above | Fail through the installed public entry point, correct input, and render again. |
| Distribution | Metadata inspection only | Import the actual distributed package. Verify samples, license notices, shader inclusion in a player build, upgrade behavior, and removal. |
| Accessibility | Not observed | Check keyboard, focus, labels, and errors for provided interfaces. For a headless library, check CLI diagnostics instead. |

No global installation, user-project modification, manual deployment, or manual release occurred.
Native applications present on the machine are not evidence of a qualified host workflow.

### Native observations, 2026-09-24 (full gate, current authority — pass 2)

Source `2344c30` vs pinned authority worktree `noisemaker@c9ee8a04` (v1.0.176). Unity 6000.3.16f1, isolated consumer, Linear, Metal; goldens from the reference WebGL2 renderer off the pinned worktree. All declared fixtures executed, zero skips, all gates exit 0: graph 316/316 byte-clean; render 112/112 (100 `PASS`, 12 measured bounded `ALLOWED_NEAR`, 0 fail); compiler contract tests PASS. Authority provenance is resolved (immutable worktree, tag `v1.0.176`); goldens were regenerated, not replaced silently — historical measurements remain in the initial probe below. Details: [compatibility report §3](COMPATIBILITY.md#3-parity-coverage).

### Native observations, 2026-09-24 (initial bounded probe)

Unity 6000.5.5f1 with an isolated embedded package and Linear color space. 19 selected fixtures rendered. Exact comparison: 4 passes and 15 differences. The 109 tracked fixtures include 39 root fixtures and 70 v104 fixtures. Twenty root graphs were absent.
The candidate source is the source listed in the [compatibility report](COMPATIBILITY.md#1-source-and-authority-revisions).
These probes compare retained historical goldens. They do not establish full current-authority parity.
90 of 109 tracked fixtures did not execute in this bounded pass.
[Per-case measurements](COMPATIBILITY.md#native-observations-2026-09-24) retain every difference and the unexecuted fixture inventory.
No gap closes. The next rendered gate must include all missing fixtures and resolve authority provenance without replacing goldens.

## 4. Known gaps

P1 means false completion or major correctness failure. P2 means coverage or integration uncertainty. P3 means documentation inconsistency.
These initial entries record missing qualification, not inferred implementation defects. No gap closes during this pass.

### GAP-001: current authority and parity qualification

- Status: open. Priority: P2. Category: verification.
- Affected scope: unity/com.noisemaker.hlsl/package.json, unity/com.noisemaker.hlsl/Samples~/QuickStart/, parity/, README.md
- Expected behavior: Each supported claim has reproducible evidence tied to the port and authority revisions.
- Observed behavior: Package metadata declares Unity 6 (`6000.0`), aligning with verified `6000.3.16f1`. The obsolete 2021.3 minimum declaration was dropped across package manifest and docs. Pass 2 (2026-09-24): current graph and image gates executed at the pinned authority — graph 316/316, render 112/112 (100 PASS + 12 measured bounded exceptions, exit 0), compiler contract tests PASS. What remains open is the broader host/platform matrix (Windows/Linux) and per-effect parameter/state/input breadth.
- Evidence: [Historical claim](https://github.com/noisefactorllc/noisemaker-for-unity/blob/d48de74c806213789bf1ed8d79ebd8e918437c57/README.md), the bounded checks in section 3, and the pass-2 gate table in [COMPATIBILITY.md §3](COMPATIBILITY.md#3-parity-coverage).
- Next action: Extend per-effect parameter/state coverage toward unrendered effects in the catalog; qualify broader platform matrix (Windows/Linux). Declared-minimum host qualification is complete for Unity 6.
- Dependencies: Resolve immutable authority inputs before comparison. Retain historical goldens and their provenance.
- Acceptance criteria: Record every applicable case, parameter choice, exclusion, error, and tolerance. Pass the declared contract without silently reducing coverage.
- Required checks: Existing compiler and parity entry points from the README, with raw results and exact source hashes.
- Last verification: 2026-09-24. Full behavior qualification remains unverified.

### GAP-002: installed developer workflow qualification

- Status: open. Priority: P2. Category: usability.
- Affected scope: Public API, README examples, supported host versions, and lifecycle behavior.
- Expected behavior: Developers can install, produce useful output, integrate it, diagnose errors, recover, and remove the package.
- Observed behavior: This pass did not observe the complete installed workflow or supported-platform matrix. Pass 3 (2026-09-24): the isolated-consumer workflow is now qualified — Quick Start imported, Play-mode test renders the bundled graph to 512×512 ARGBHalf and binds it to the material (PASS); public-API error paths verified (documented no-source error; corrupt JSON raises `FormatException`); macOS player build succeeds with the automatic `NMShaderInclusionBuildStep` and the headless player reproduces the workflow with shaders resolved at runtime (PASS). Pass 4 (2026-09-24): removal and reinstall lifecycle verified clean. Pass 6 (2026-09-24): package minimum host requirement aligned to Unity 6 (`6000.0`), dropping obsolete 2021.3. Still open: supported-platform/OS matrix (Windows/Linux) and upgrade path (single shipped version today).
- Evidence: [README](https://github.com/noisefactorllc/noisemaker-for-unity/blob/d48de74c806213789bf1ed8d79ebd8e918437c57/README.md), [ecosystem reference](https://docs.unity3d.com/6000.0/Documentation/Manual/upm-ui-local.html), and section 3.
- Next action: Import the local UPM package into an isolated project. Import Quick Start, select Linear color, press Play, and verify a player build.
- Dependencies: Use an isolated consumer and the intended host version. Identify any required GPU, license, or external input before testing.
- Acceptance criteria: Retain the installed artifact hash, interaction steps, meaningful output, recovery result, and cleanup result.
- Required checks: Test minimum and current supported versions. Measure cancellation and file preservation where relevant. Record unavailable platforms explicitly.
- Last verification: 2026-09-24. Source inspection does not close this gap.

### GAP-003: distribution and release qualification

- Status: open. Priority: P2. Category: release.
- Affected scope: Distribution artifact, dependency metadata, notices, platform promises, and release evidence.
- Expected behavior: The delivered artifact contains required files and supports its documented installation and first useful result.
- Observed behavior: Metadata and CI alone did not qualify the artifact. Pass 4 (2026-09-24): local artifact integrity verified (embedded package checksum-identical to the source tree, `.meta` included); package metadata verified (MIT + LICENSE.md, zero dependencies, 1 sample, wired URLs); removal → clean import verified; re-embed → play-mode suite 3/3 PASS verified. Pass 5 (2026-09-24): the *distributed* kit (`0.1.17`) is published at source `2344c30` — the exact tested revision — and all 2107 inventoried files verify byte-for-byte against the served manifest (sha256 + size, fail-closed, 0 bad); exact-source CI (Export kit, run 35984719956) reports `success` at that SHA. Remaining: the upgrade path (single shipped version today) and host/platform matrix.
- Evidence: [Package instructions](https://github.com/noisefactorllc/noisemaker-for-unity/blob/d48de74c806213789bf1ed8d79ebd8e918437c57/README.md), exact-source CI in section 2, and recorded distribution observations in section 1.
- Next action: Import the actual distributed package. Verify samples, license notices, shader inclusion in a player build, upgrade behavior, and removal.
- Dependencies: Complete GAP-002 for the release candidate. Distinguish source CI from downstream publication and host qualification.
- Acceptance criteria: Match artifact bytes to the inventory. Check licenses and dependencies. Pass installation, example execution, upgrade, and removal.
- Required checks: Inspect required CI jobs at the exact source SHA. Count skips and verify actual render legs, not green summaries.
- Last verification: 2026-09-24. No package or release approval follows from this register.

## 5. Ordered next actions

1. Resolve authority revisions and retained evidence for GAP-001. Preserve all previous comparisons and exclusions.
2. Run the bounded installed workflow for GAP-002. Record output, errors, recovery, host version, and resource cleanup.
3. Execute the declared parity cases for GAP-001. Keep compilation, structure, rendered pixels, and platform qualification separate.
4. Qualify the actual distribution for GAP-003 after the workflow passes. Verify exact-source CI and required artifact contents.
5. Update this register with measured results. Close entries only when their acceptance criteria pass.

Implementation changes belong to the separate implementation job. This register does not authorize further effect ports or checkpoint advancement.

## 6. Pass history

| Date | Source SHA | Changes | Tested scope | Remaining limits |
|---|---|---|---|---|
| 2026-09-24 (pass 6) | current source | Host requirements aligned to Unity 6 (`6000.0`): package manifest and docs updated to mandate Unity 6 (`6000.0+`); obsolete 2021.3 minimum declaration dropped; closes minimum host qualification debt. | Package metadata, compiler contract tests, Play-mode test suite, and consumer docs. | Platform/OS matrix (Windows/Linux), upgrade path (single shipped version), per-effect parameter/state coverage. |
| 2026-09-24 (pass 5) | `2344c30211c73804989647058506a387de404c91` | Distributed-kit verification: served kit `0.1.17` published at source `2344c30` (the tested revision); all 2107 inventoried files fetched and verified against the manifest (sha256 + bytes, fail-closed, 0 bad); exact-source CI (Export kit, run 35984719956) `success` at that SHA. | Distributed artifact byte-verified against its inventory at the tested source. | Upgrade path (single shipped version), host/platform matrix remain open (GAP-003). |
| 2026-09-24 (pass 4) | `2344c30211c73804989647058506a387de404c91` | GAP-003 local qualification: embedded package checksum-identical to source tree; metadata verified (MIT, LICENSE.md, zero dependencies, 1 sample, wired URLs); removal → clean import; re-embed → 3/3 play-mode suite PASS. | Removal/reinstall lifecycle verified; artifact-integrity and metadata checks recorded. | Distributed-kit byte check, upgrade path, host/platform matrix remain open (GAP-003). |
| 2026-09-24 (pass 3) | `2344c30211c73804989647058506a387de404c91` | Installed-workflow qualification: Quick Start play-mode test (render + material binding), public-API error/recovery legs (no-source error path; corrupt JSON raises `FormatException`), macOS player build with runtime shader resolution via the automatic `NMShaderInclusionBuildStep`. | Play-mode suite 3/3 PASS; headless player reproduces the workflow (512×512 ARGBHalf, material bound, stats identical to editor). | Platform/OS matrix, 2021.3 minimum host, upgrade/removal lifecycle, distributed-artifact checks remain open (GAP-002/GAP-003). |
| 2026-09-24 (pass 2) | `2344c30211c73804989647058506a387de404c91` | Authority pinned to immutable worktree `noisemaker@c9ee8a04` (v1.0.176); all goldens/graphs regenerated; root/3D/v104/tiled render gates + graph gate + compiler contract tests executed; three previously unbounded root fixtures formalized in `programs/exceptions.json` with measured budgets; added `programs/manifest.tsv` and `parity/root-verify.sh`; registers refreshed. | Graph 316/316 byte-clean. Render 112/112 (100 PASS + 12 bounded ALLOWED_NEAR, 0 fail), all gates exit 0. Contract tests PASS. | Declared-minimum host (2021.3) and platform matrix unqualified; per-effect parameter/state breadth open; GAP-002 (installed workflow) and GAP-003 (distribution) open. |
| 2026-09-24 | `d48de74c806213789bf1ed8d79ebd8e918437c57` | Created the requested six-section register and README link. No closures. | 27 Python comparator tests passed. A later native batch rendered 19 graphs. Full current-authority parity and player workflows remain unverified. | Full audit, current parity, installed workflows, platform qualification, and release readiness remain open. |

Run ID: `20260924-remaining-gap-documents`.
[Operational evidence](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents). Queue position and successful-audit timestamps remain unchanged by document creation.

2026-09-24 report initialization: added the maintained compatibility report and bounded native measurements. No full-parity closure.
