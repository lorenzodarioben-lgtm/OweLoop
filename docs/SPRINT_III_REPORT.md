# Sprint III execution evidence

Executed 2026-10-28, Australia/Sydney, from clean/synchronized
`8c3a1af06033f47c0e5f163e3870ec731956685b` on `codex/functional-completion`.
[PR #8](https://github.com/lorenzodarioben-lgtm/OweLoop/pull/8) stays draft/unmerged.
No merge, deployment, release or hosted/production data operation occurred.
Resolve the final SHA with Git and PR state; a file cannot record its own commit.
The [changed-file manifest](SPRINT_III_FILES.txt) is generated from Git against
that baseline. Existing handover and historical Sprint II evidence remain.

## Implemented behavior

Recovery locks before loading account storage and serializes read/modify/write;
explicit retries retain the original operation ID/payload and reaffirm persistence
before every send. Delayed-storage regressions reproduce both former races.
Android secure storage 11.2.0 acknowledges asynchronous apply before disk writes;
a narrow worker-thread native fence waits for config/key/data commits. False,
failure or a 15-second deadline prevents sending. No credential/payload traverses
the channel. See [ADR 0017](decisions/0017-android-secure-storage-durability.md).

The existing emulator runner now force-stops/relaunches the actual process for
unsent draft save/restore, in addition to four financial recovery checkpoints.
It checks exact/date/category/non-equal fields, Auth reload, removed payer review
without reallocating debt, account B isolation, zero financial rows and cleanup
preserving unknown operations. Form actions have separate widget coverage; the
probe uses production store/review logic. A withheld-marker test proves timeout.

Review-only recurrence creates schedules from immutable template snapshots,
with daily/weekly/fortnightly/monthly server-calendar dates and explicit IANA zones.
Month ends clamp without anchor drift. Discovery bounds are 90 days and 100
schedules/group; history uses keyset pages. Create/edit/pause/resume/cancel/skip
controls lead to the ordinary explicit expense form. Unique occurrence identity,
revision/group locks and atomic expense/completion handling prevent duplicate
reviewers; lost responses retain the saved original operation ID. Templates,
removed members, archive/reopen and account deletion are revalidated. No cron or
automatic posting. See [ADR 0015](decisions/0015-bounded-review-only-recurrence.md).

Private PNG/JPEG receipts use bounded content/type/dimension validation, opaque
keys, digest-bound intents, append-only events, current-membership authenticated
downloads and restrictive Storage policies. Client direct writes and service RPCs
are denied. Trusted completion follows real upload; uncertain completion never
removes a possibly ready file. Delete revokes reads before removing the object;
failed deletion is retryable. Service-only timestamp-guarded stale cleanup removes
old unfinished/orphan files and preserves ready files. Archive/void/removal and
account deletion follow [ADR 0016](decisions/0016-private-receipt-gateway.md).
Images are memory-only in the app, evicted on account changes; stale callbacks
are ignored. No public/signed URL is generated. Structural validation is not an
antivirus or full image decoder. Native picker behavior is separately unverified.

Optional local Storage/Edge setup is isolated; existing env/config are preserved.
A fresh temporary source-folder rehearsal used existing installed CLI dependencies,
passed first/repeated start and own-stack stop. It was not a cold-cache clone
rehearsal. Receipt controls require `OWELOOP_RECEIPTS_ENABLED=true`. Pinned
`file_selector` 1.1.0 is the only new direct runtime package; no hosted setup.
Startup wrappers suppress CLI credentials, including optional S3 keys.

Real loopback TCP tests close connections before forwarding and after draining
actual upstream SQL success. Same-ID recovery yields one expense. Actual local
`/functions/v1/delete-account` checks cover auth/method/password/ownership,
forged-other-ID resistance, retained history and deleted-token denial. These
are actual gateway/TCP results, not physical network-transition evidence.

Migration 29 aggregates allocation validation and materializes canonical member
rows once, retaining all caller/range/integrity/zero-sum checks. Two independent
rollback-fixture comparisons require exact ordered equality with the released
read function. Three alternating warm samples per cohort showed 13–38% lower
medians; largest fixtures changed 1.90→1.61s and 1.98→1.72s with variance.
Actual HTTP reads verified full counts/zero sum: the largest expense response
was 2,350,000 bytes and Node maximum RSS was 74,358,784 bytes. This is neither
cold-cache nor Flutter/device memory evidence. See [ADR 0018](decisions/0018-aggregate-balance-validation.md),
[methodology](performance.md) and [samples](SPRINT_III_BENCHMARK.json).

## Verification and CI

Final local commands:

- Dart format check, `flutter analyze`, `flutter test`: 205 ordinary passes,
  four configured live skips. Large-text tests use 375px/2× text. Additional
  regressions cover delayed schedule refresh/skip and receipt download after
  sign-out, plus failed/unresponsive secure-store fences.
- `./scripts/check-local.ps1 -SkipInstall -DartIntegration -StorageAndFunctions`:
  29 migrations, 483 pgTAP assertions across 17 files, schema lint, populated
  20+9 and 26+3 upgrades preserving snapshots/balances, 58 financial/recurrence
  HTTP assertions, nine actual deletion gateway checks, fourteen real receipt/
  Storage assertions, four live SDK tests and thirteen Node tests.
- Adding `-Benchmark` ran both SQL comparisons and actual HTTP measurements on
  disposable stacks. Each helper stopped only its own project in finally.
- Markdown target checks and `git diff --check`; original 26 migrations unchanged;
  no env, credentials, signing files or generated build output committed.

Earlier checkpoint evidence: `57f13f7` passed
[native](https://github.com/lorenzodarioben-lgtm/OweLoop/actions/runs/40523228599).
`c440f11` passed Mobile/Database including the actual Edge job; native draft resume
failed with a type error. Sanitized stage reporting and source inspection led to
the independent durability fix; the type error's sole cause was not established.
`43700d6` passed [native API35](https://github.com/lorenzodarioben-lgtm/OweLoop/actions/runs/40532675974),
including the real schedule UI journey and all six process checkpoints with the
native disk fence, plus [Mobile CI](https://github.com/lorenzodarioben-lgtm/OweLoop/actions/runs/40532682283).
Some database starts hit external image-registry limits before tests. Final
exact-head Mobile/Database/native results and URLs are recorded in PR #8 and the
delivery report; earlier successes never substitute for a current-head check.

## Limits and next action

Physical Android/iOS/Keychain, native picker/share destinations, TalkBack/VoiceOver,
platform network transitions/callbacks, signing, hosted gateways/SMTP, backup/
restore and staffed privacy/support remain release gates. Mailpit callback
instructions are documented, not an executed native callback result. PDF/WebP,
schedule end dates, persisted selected receipt bytes, full offline sync,
localization/reminders, OCR and payments are omitted. Complete snapshots/exports
still materialize in memory; native sharing has a 20 MiB cap.

The next independent Claude Code task is delayed recurrence create/edit-dialog
A→B→A session coverage; refresh/skip regressions already exist. Exact files,
branch and acceptance are in [HANDOFF](../HANDOFF.md) and [roadmap](roadmap.md).
