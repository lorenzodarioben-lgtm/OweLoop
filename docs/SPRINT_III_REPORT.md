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

## Recurrence milestone

Migration `20261028000000_review_only_recurrence.sql` is forward-only after the
existing 26. RLS/direct-DML denial, creator/admin optimistic edits, current-member
review/skip, archive/removal/deletion, immutable pinned templates and atomic
expense completion are covered by 44 additional pgTAP assertions (448 total).
Four calendar cadences, leap years, DST and monthly clamping are server based.
Discovery deliberately omits ungenerated dates older than 90 days; 100 schedules
per group and keyset occurrence pages bound work. No end-date control or worker.

Reachable Material controls create from a template, list schedules, edit/pause,
cancel, show next dates, review, skip and open completed expenses. Reviewing opens
the ordinary form and sends nothing until Post expense. Persistence/lookup/retry
remain the existing expense operation type with a saved occurrence reference.
194 ordinary Flutter tests pass, with two live skips. New tests cover calendar
input, review without posting, explicit-post identity, skip confirmation, stale
errors and large text on a 375px phone. Analysis is checked separately.

Actual local `check-local.ps1 -SkipInstall -DartIntegration` passed fresh 27
migrations, 448 pgTAP assertions, schema lint, six handler tests, populated 20+7
upgrade, 58 real HTTP assertions and two live SDK tests. HTTP cases include
concurrent discovery, lost-response/multi-account completion, conflicting replay,
pause, skip, template edit, paging, archive/reopen, removal and export. The helper
also passed the populated 26+1 Sprint II upgrade, retaining eleven table snapshots
including templates and canonical balances.

Recovery checkpoint `57f13f7` passed [API35 native CI](https://github.com/lorenzodarioben-lgtm/OweLoop/actions/runs/40523228599):
UI journey and before/resume-before/after/resume-after/draft/resume-draft.
[Mobile CI](https://github.com/lorenzodarioben-lgtm/OweLoop/actions/runs/40523239245)
and the rerun [Database CI](https://github.com/lorenzodarioben-lgtm/OweLoop/actions/runs/40523239243)
passed. Initial database jobs failed image-registry downloads, before tests.
Local Docker later started successfully; isolated stacks were individually stopped.

## Remaining assignment

## Private receipt milestone

Migration 28 adds private metadata/events and restrictive Storage policies, with
RPC-only caller intents and service-only completion/cleanup. The trusted Edge
gateway validates bounded PNG/JPEG structure/type/dimensions and binds each upload
UUID to its caller/expense/digest/type/size. An unknown finalize response never
deletes a possibly ready object. Authenticated downloads recheck membership;
archive/void/removal/account deletion retain the documented privacy/audit policy.
Only uploader/admin may explicitly delete in active groups. No public URL exists.

Actual isolated validation passed 28 migrations, 476 pgTAP assertions, lint,
20+8 and 26+2 populated upgrades, 58 financial/recurrence API assertions, nine
actual deletion gateway checks, thirteen Storage/gateway assertions and four live
SDK checks. Stale orphan cleanup removed an actual file and preserved an old ready
attachment. Five Node handler tests pass, including lost completion/deletion
failures. Full Flutter tests pass 201 with four configured live skips; five new
receipt tests verify picker cancellation, explicit same-ID retry, account change,
bounded file selection and 375px large text. Native picker/device/iOS behavior
remains unrun; Android compilation is checked separately by CI.

`file_selector` 1.1.0 is the only new direct runtime dependency; Flutter renders
images. PDF/WebP and durable selected bytes across process death are omitted.
After restart refresh server state and explicitly delete an unfinished upload
intent before reselecting; financial operation recovery is separate and preserved.

`dev:start -- --storage` enables only the generated local Storage/Edge config and
copies functions. A fresh temporary source-folder rehearsal used the existing
installed CLI via a dependency junction: initial start/env creation, repeated
start/env preservation and status passed, then its own backend stopped. This was
not a cold package-cache install or a complete clone rehearsal. Normal app builds
hide controls until `--dart-define=OWELOOP_RECEIPTS_ENABLED=true`.
`receipts:cleanup` accepts process-only local service credentials, never reads the
mobile env and refuses hosted URLs; batches are limited to fifty with a cursor.

## Wire resilience and actual local gateway

`check-local.ps1 -SkipInstall -StorageAndFunctions -DartIntegration` passed on
the disposable local Storage/Edge stack: 448 pgTAP, both populated upgrade paths,
58 API assertions, nine actual Edge gateway assertions and four live SDK tests.
The new SDK cases use a real loopback TCP proxy: before-send socket closure
forwards no financial POST; after-commit closure drains real upstream success
before dropping the response. Recovery retains original payload/ID and exactly
one expense. This is HTTP/TCP evidence, not physical network-handoff testing.

The gateway suite calls `/functions/v1/delete-account` rather than importing the
handler. It verifies authentication, password/ownership blockers, exact caller
deletion despite a forged other-user ID, retained history and deleted-token denial.
The initial harness wrongly required HTTP 200 for a void RPC returning 204;
the harness was corrected and the complete suite rerun successfully.

At `00ef923`, Database CI passed. Mobile/native CI exposed a duplicated `post`
test variable in the native recurrence journey, corrected before the next push.
No failed native result is represented as a recurrence runtime pass.

`c440f11` passed Mobile/Database CI, including the actual local Edge job. Its
native probe passed four financial checkpoints but failed draft resume with a
type error. Sanitized stage reporting now identifies the location. Independent
source inspection found the Android secure-store write uses asynchronous apply;
ADR 0017 adds a worker-thread disk fence and reaffirms persistence on every retry.
Fifteen focused durability/recovery tests pass. Native bridge execution follows.

Private receipts, actual network-fault resilience, scale
measurements, local Edge gateway and practical accessibility remain to be evaluated
in successive milestones. A configured test is not evidence of execution.
