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

### Native observations, 2026-09-24

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
- Observed behavior: Package metadata declares Unity 2021.3, while README verification names 6000.3.16f1. The declared minimum lacks fresh qualification here.
- Evidence: [Historical claim](https://github.com/noisefactorllc/noisemaker-for-unity/blob/d48de74c806213789bf1ed8d79ebd8e918437c57/README.md) and the bounded checks in section 3.
- Next action: Run current graph and image gates. Preserve the 20-case historical denominator and separate tolerances until current evidence replaces them.
- Dependencies: Resolve immutable authority inputs before comparison. Retain historical goldens and their provenance.
- Acceptance criteria: Record every applicable case, parameter choice, exclusion, error, and tolerance. Pass the declared contract without silently reducing coverage.
- Required checks: Existing compiler and parity entry points from the README, with raw results and exact source hashes.
- Last verification: 2026-09-24. Full behavior qualification remains unverified.

### GAP-002: installed developer workflow qualification

- Status: open. Priority: P2. Category: usability.
- Affected scope: Public API, README examples, supported host versions, and lifecycle behavior.
- Expected behavior: Developers can install, produce useful output, integrate it, diagnose errors, recover, and remove the package.
- Observed behavior: This pass did not observe the complete installed workflow or supported-platform matrix.
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
- Observed behavior: Distribution metadata was inspected. Complete artifact reproduction, installation, upgrades, and removal remain unverified.
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
| 2026-09-24 | `d48de74c806213789bf1ed8d79ebd8e918437c57` | Created the requested six-section register and README link. No closures. | 27 Python comparator tests passed. A later native batch rendered 19 graphs. Full current-authority parity and player workflows remain unverified. | Full audit, current parity, installed workflows, platform qualification, and release readiness remain open. |

Run ID: `20260924-remaining-gap-documents`.
[Operational evidence](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents). Queue position and successful-audit timestamps remain unchanged by document creation.

2026-09-24 report initialization: added the maintained compatibility report and bounded native measurements. No full-parity closure.
