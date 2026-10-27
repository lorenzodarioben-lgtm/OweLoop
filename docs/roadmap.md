# Roadmap and incoming developer queue

The two functional sprints delivered the shared-expense core, guarded exact
financial operations/recovery, lifecycle/account handling, complete history,
categories/templates, private exports/sharing, inbox and device settings.
See [functional inventory](FUNCTIONAL_COMPLETION_REPORT.md), [Sprint II evidence](SPRINT_II_REPORT.md)
and [HANDOFF](../HANDOFF.md). Code availability is separate from release readiness.

## P1 — First independent contribution: recurrence editor session races

Add delayed-repository widget tests for signing out or switching accounts while
schedule create/edit/skip dialogs or refresh are pending. Files:
`mobile/test/features/expenses/expense_schedules_test.dart`,
`mobile/lib/features/expenses/presentation/expense_schedules_screen.dart` and
`expense_templates_screen.dart`. Assert no action authorized by A is submitted
as B, no A content reappears and busy states recover. Change production only for
a reproduced defect. Run formatting/analysis/full Flutter and native CI.

## Completed — native unsent draft restart coverage

Completed in Sprint III: the actual API35 emulator run passed the new draft and
resume-draft checkpoints plus all four financial checkpoints. See
[Sprint III](SPRINT_III_REPORT.md). The original acceptance contract follows.

- **Motivation/current:** real-process tests cover pending financial operations;
  unsent draft save/restore has unit/widget coverage but no actual restart probe.
- **Expected:** save an unsent expense draft through the real secure store,
  terminate/relaunch the emulator app, explicitly restore it and retain fields,
  category and active participants. Never post merely by saving/restoring.
- **Files:** `mobile/integration_test/recovery_probe_app.dart`,
  `scripts/test-android-recovery.mjs`,
  `mobile/lib/features/expenses/data/expense_draft_store.dart`, relevant existing
  draft widget tests. Change production source only if the test finds a defect.
- **Dependencies:** Android/JDK/ADB + disposable local Supabase, or the existing
  native CI workflow; independent branch `test/native-draft-restart` from the
  handover branch. Use new sanitized markers, never log the draft/personal data.
- **Acceptance:** bounded before/restart/restore checkpoints, exactly zero new
  expenses before explicit posting, account B cannot restore A's draft, inactive
  participants handled, pending operations unaffected. Existing native four
  checkpoints and levels 1–4 remain passing; update HANDOFF with real evidence.

## P0 — Gates before distributing a beta

These tasks require hardware, credentials or operator decisions. Preparing code/
checklists locally is allowed; provisioning, deployment and release require the
owner's explicit authorization. Never infer authorization from this backlog.

| Task | Current → expected / motivation | Files / dependencies | Verification |
| --- | --- | --- | --- |
| Physical Android acceptance | Emulator passes; hardware Keystore, network handoff, account switch, callbacks, shares and accessibility unverified → recorded device results | `mobile/android/`, `core/operations/`, [test plan](private-beta-test-plan.md); Android phone/SDK/JDK, signing access for release variant | Restart/lost response preserves same ID; draft restoration; airplane/Wi-Fi transitions; share destination and cancellation; back/deep links; large text/TalkBack; controlled signed build |
| iOS acceptance | No local Xcode/Keychain execution → equivalent iOS evidence | `mobile/ios/`, export/secure-store code, [native testing](native-recovery-testing.md); macOS/Xcode, device, Apple signing | Build, simulator then physical restart/account isolation; Keychain, iPad share origin/cancellation, callbacks and VoiceOver; record build/OS/commit |
| Approved beta backend/lifecycle | No hosted target/SMTP/Edge validation → tested approved beta, never production reset | `supabase/functions/delete-account/`, ordered migrations, [hosted runbook](hosted-beta-environments.md), [auth redirects](auth-redirects.md); owner approval, operator account/secrets | Backup and restore rehearsal before migrations; email verification/reset links; deployed gateway wrong-password/blocker/exact-user deletion and retained-history/old-token denial |
| Staff operational processes | Privacy/support/consent/incident values unconfigured → named owners and reviewed notices | [operations](private-beta-operations.md), [release checklist](private-beta-release-checklist.md), [account lifecycle](account-lifecycle.md); owner/legal/support decisions | Published retention/data-use expectations, staffed ownerless recovery case procedure, tester consent, incident/crash-reporting and backup owners; checklist evidence before distribution |

Use [testing level 5](testing.md) and the release checklist; a local green test
suite does not complete any of these gates. No public beta/store readiness claimed.

## P1 — Large-group resource validation

**Local engineering plus later device checks.** SQL fixtures pass up to 1,000
members/2,000 expenses/1,000 settlements; canonical balances take about 1.7 s locally.
Whole memberships, balances and exports still materialize in memory. Expected:
measure network payload, memory, scrolling and reconciliation latency before
setting supported limits or optimizing. Files: `scripts/benchmark-local.mjs`,
`expenses/data`, `balances/data`, group/history widgets and `core/operations/export_sharing.dart`
under `mobile/lib/`; [existing observations](performance.md). Requires local Docker,
then Android/iOS profiling hardware. Accept only invariant-preserving changes;
compare EXPLAIN/complete counts, exact balances and multi-page traversal plus
actual device measurements. No timing target should be invented from one SQL run.

## P2 — Optional product work, independently scoped

| Task | Current → expected / motivation | Relevant files / dependencies | Acceptance |
| --- | --- | --- | --- |
| Secure receipts | No attachment feature; Storage disabled → private authorized image/PDF workflow | New ordered migration and storage tests; `supabase/config.toml`, expense feature; reviewed local Storage/retention model before hosted setup | Unauthorized/cross-group/removed access denied, bounded MIME/size/path, orphan cleanup, archive/void/delete/export behavior tested; no public URLs or service role in app |
| Scheduled recurring drafts | Reviewed reusable templates only → deterministic due drafts that never auto-post | Expense template domain/repository, new schedule migration if needed; explicit timezone/member/archive policy | Month end, DST/timezone, missed periods, edits/pause/cancel, concurrent/open-repeat dedupe and explicit financial confirmation |
| Localization | English labels only → reviewed locale/currency/date presentation | `mobile/lib/` presentation and supported currencies; product locale decisions | Exact parsing/formatting unchanged, long text/layout, semantics and locale tests |
| Broader offline support | Secure unsent drafts/manual uncertain-operation recovery → clear stale/offline reads and controlled unposted intentions | Auth/session controllers, repositories, operations/draft stores; scope/retention decision | Account isolation, reconnect revalidation, no silent loss or automatic financial posting; never replace authoritative balance with speculative success |
| Notification delivery | Manual-refresh private inbox only → explicitly opted-in delivery | Notification feature/current authorization RPCs; delivery provider/credentials and owner approval | No unknown-email enumeration, removed-user details or duplicate delivery; current source authorization, opt-out/privacy tested |

Unknown-email requests intentionally remain unbound. Revoke/resend after signup;
any future pre-registration delivery model needs a reviewed identity/privacy model.
Do not add an identity directory or weaken source authorization as a shortcut.

## Visual design boundary

Existing routes and domain/repository contracts are stable enough for a separately
scoped presentation phase. [DESIGN_HANDOFF](DESIGN_HANDOFF.md) is the neutral screen/
state reference. Preserve exact amounts, durable identities, permissions, explicit
posting/void confirmations, readable errors, pending/unknown recovery states and
account/session guards. Design work must not claim missing native/hosted release
evidence, hide uncertainty or silently edit financial history. No aesthetic choice
is prescribed by this handover.
