# Sprint III execution evidence

Started 2026-10-28, Australia/Sydney, from
`8c3a1af06033f47c0e5f163e3870ec731956685b` on `codex/functional-completion`.
[PR #8](https://github.com/lorenzodarioben-lgtm/OweLoop/pull/8) remains draft.
No merge, deployment, release or hosted data operation is authorized or performed.

## Recovery milestone

Two reproduced races are fixed: reconciliation previously read before locking
and could overwrite a concurrent saved unknown request; retry could create a new
ID if reconciliation confirmed its stale read. Recovery now locks before reading,
keeps the lock through persistence and explicitly retains the original retry ID.
Regression tests use delayed storage to exercise the interleavings and lock release.

The debug-only native probe adds actual draft/resume-draft process checkpoints.
It checks secure-store field equality (date/category/exact split), Auth reload,
inactive-payer review without reallocation, account B isolation, no financial
records and draft cleanup preserving unresolved requests. This is a store/domain
probe; existing widget tests separately exercise explicit form save/restore.
The Node marker tests include a controlled timeout with a withheld checkpoint.

Baseline: 22 focused recovery/expense widget tests passed before changes.
Recovery milestone: formatting and analysis pass; 190 Flutter tests pass, two
configured live tests skip; 26 focused tests and two Node marker tests pass.
Documentation links and `git diff --check` pass. Exact pushed-head CI follows.
Docker Linux-engine pipe is absent even after a bounded Desktop start attempt;
ADB is not on PATH and no local emulator is configured. These are environmental
blocks, not backend/native passes. Physical Android/iOS remain unverified.

## Remaining assignment

Review-only recurrence, private receipts, actual network-fault resilience, scale
measurements, local Edge gateway and practical accessibility remain to be evaluated
in successive milestones. A configured test is not evidence of execution.
