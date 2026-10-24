# Functional completion report

Updated 2026-10-25, Australia/Sydney. Branch: `codex/functional-completion`.
Base master: `9fe698836488288fac704801f13683d3844bf4cc`.
Draft [PR #8](https://github.com/lorenzodarioben-lgtm/OweLoop/pull/8).
Sprint II extends `280b86dd9f67a1fecd25de97c185d9febd856ceb`; the five first-sprint
commits and all twenty existing migrations are preserved. See [HANDOFF](../HANDOFF.md)
for the next developer's starting point and [Sprint II](SPRINT_II_REPORT.md) for
checkpoint/evidence details. Resolve exact delivery HEAD with `git rev-parse HEAD`;
a tracked document cannot contain its own containing commit's hash.

## Delivered behavior

The repository already had the Version 0.1 core. Both sprints strengthen and
extend it with plain Material screens. No visual redesign, payment processing,
production deployment, merge or release is included.

| Area | Implemented behavior | Evidence and practical limit |
| --- | --- | --- |
| Money/allocation | Checked native-bigint bounds, BigInt intermediates, equal/exact/percentage/weighted Hamilton allocation | Eight currencies, deterministic remainder/zero-weight and generated invariant tests; no floating point |
| Financial integrity | Guarded atomic creation, immutable posted rows, authorized void/duplicate, canonical zero sum | SQL/adversarial/concurrent HTTP checks; no debt forgiveness |
| Authorization | Direct mutation grants revoked; current caller, RLS, stable locks, durable member UUIDs | Owner/admin/member/removed/outsider/anonymous tests; server credentials absent from Flutter |
| Financial recovery | Secure account-scoped persist-before-send, manual status/retry, original payload/ID, unknown states retained | Lost-response/storage/account-switch tests, real SDK transport tests; native runtime status below |
| Auth/profile | Existing email/signup/verification/recovery flows, profile edit, generation guards | Delayed Auth/profile race tests; physical email callbacks and hosted SMTP unverified |
| Navigation | Nested root/group/form/history/settings/export routes; sign-out removes protected content | Widget journeys and native harness; device system-back gate remains |
| Groups | Atomic creation, guests, registered memberships, safe roles/ownership/removal/leave/archive | Real Auth/PostgREST and pgTAP; guests have no anonymous Auth authority |
| Archive recovery | Owner-only idempotent audited reopen; service-role-only ownerless recovery to an existing active registered successor | Authorized/unauthorized/race/history-preservation checks; operator procedure must be staffed |
| Collaboration | Recipient-bound invitations and explicit same-ID guest claims | Concurrent acceptance/privacy checks; unknown emails stay unbound, revoke/resend after signup |
| Expenses | Multi-payer flexible exact splits, optional immutable category, details/audit/void/duplicate | Category across form/draft/template/history/CSV; legacy operation payloads/RPCs preserved |
| History | Lazy keyset pages, expense search/category/date/member/void filters; settlement date/payer/receiver/amount/state/order filters | Equal-date/boundary and multi-page SQL tests, controller stale-page tests; full lists isolated from previews |
| Drafts | Explicit account/group secure Save/Restore/Discard | Unsent restore never posts; cleanup copies key list and preserves another account/unknown operations; no full offline sync |
| Templates | Shared validated defaults, review, save/update/delete, creator/admin authority and optimistic conflict | SQL/widget/HTTP checks; inactive participants filtered, inactive payer cleared; no recurrence or autopost |
| Ledger exports | Complete single-statement snapshots with void state, categories and exact allocation JSON | Concurrent export/void and snapshot checks, formula protection; whole export materializes in memory |
| Sharing | Explicit CSV/personal JSON native sharing with private account files, MIME, 20 MiB cap, cancellation/error/expiry cleanup | Real temporary-file and injected-share tests; destination import/device sheets unverified |
| Personal export/deletion | Caller-only exact JSON, readable templates/read markers, password-confirmed trusted deletion and retained shared history | Real local Admin deletion and old-token denial plus six handler tests; hosted Edge gateway unverified |
| Private inbox | Current authorized financial/lifecycle and recipient-bound request sources, pages, unread filter/read markers/source links | SQL isolation/removal/deletion/cursor tests and reachable widget test; manual refresh, no push/email |
| Device settings | Secure account/device default currency and confirmed draft/export cleanup | Late-load/manual-selection race and persistence/isolation tests; not synchronized across devices |
| CI/tooling | Mobile analysis/tests/debug APK, database/upgrade/HTTP, separate emulator and force-stop harness | SDK-pinned CI, Node24 actions; keep PR draft pending release gates |
| Scale | Four rollback-only fixtures to 1,000 members/2,000 expenses/1,000 settlements | Actual SQL plans/timings in [performance](performance.md); UI/network/memory unprofiled |

## Verification

All backend executions used uniquely named disposable local stacks. No routine
check was linked to hosted data. Public/local privileged keys stayed in process
environment; no credentials or raw financial recovery payloads are committed.

| Check | Executed result |
| --- | --- |
| Dart format | 175 files checked, zero changes needed |
| Flutter analyze | No issues found |
| Ordinary Flutter unit/widget suite | 186 passed, two explicitly configured live tests skipped |
| Real Dart SDK transport | Both live tests passed after fixing absent POST-RPC lookup; missing lookup and committed-response-loss recovery |
| pgTAP | 404 assertions across 14 files passed |
| Schema lint | No schema errors/findings |
| Trusted deletion handler | Six passed |
| Real local Auth/PostgREST | 44 assertions passed with three accounts and actual Admin deletion |
| Fresh initialization | All26 ordered migrations applied |
| Non-empty upgrade | Twenty first-sprint + six Sprint II migrations; nine ledger table snapshots/canonical balances preserved |
| Rollback-only benchmark | Four fixture scales passed; largest balance 1,700.208ms, first history 1.298ms locally |
| Mobile/Android debug CI | Passed at code checkpoint `806fdef`; links in Sprint II record |
| Native Android runtime | Real APK compiled/installed; before-send barrier reached, resume failed; corrected run pending |
| Local Android build | JDK21 attempt failed before app compilation at Gradle loopback initialization; no AVD/device |
| iOS | Not executed: no macOS/Xcode/device |

The real SDK regression reproduced PGRST116/406 when `.maybeSingle()` was used
on a POST reconciliation RPC with zero rows. Lookup now requests table JSON,
returns null only for an empty list and rejects malformed/ambiguous responses.
Four wire-level tests cover absent, committed, malformed and multiple results.
No absent lookup is treated as financial rejection. Independent test Auth
clients use implicit signup rather than assuming Flutter PKCE storage exists;
production Auth is unchanged. These are actual integration mismatches found by
runtime work, not merely mock failure injection.

The HTTP journey checks concurrent five-way expense/four-way settlement replay,
conflicting payload rejection, invitation/claim races, exact categorized unequal
posting, unauthorized void, reversal, export/void concurrency, template edit
conflict, concurrent reopen and trusted ownerless recovery after real account
deletion. SQL attempts direct writes, privileged lifecycle bypasses, foreign and
removed memberships, unauthenticated access and caller-only data reads.

The first balance optimization reduced an earlier cancelled 158-second synthetic
query to 574 ms on its fixture. Sprint II's separate reproducible fixture series
adds bounded history plans and complete export/member assertions. These are
local observations and do not establish a production capacity or device result.

## Database and dependencies

Six new forward-only migrations are listed in [Sprint II](SPRINT_II_REPORT.md).
Released SQL files are unchanged. New tables contain lifecycle audit, reusable
configuration and private read state, with direct client DML revoked and narrow
function authority. ADRs 0009-0014 explain money, durable submissions, account
retention, archive recovery, templates/exports and private inbox/settings.

`flutter_secure_storage` 11.2.0 was added in Sprint I. Sprint II adds
`share_plus` 13.3.1 for maintained platform sharing and direct `path_provider`
2.1.6 (already transitive) for private cache location. Dev-only `http` 1.6.0
(already transitive) exercises real PostgREST wire behavior. No unrelated runtime
package upgrade or service dependency is introduced.

## Remaining limitations and release gates

1. Complete the corrected Android emulator UI/process-death run, then physical
   Keystore, account-switch, draft restart, network-loss, back/callback,
   TalkBack/large-text and share-destination checks. Emulator evidence is narrower
   than physical hardware, backup/restore or a release build.
2. Build/run iOS on macOS, validate Keychain, iPad sharing origin, callbacks,
   signing, VoiceOver and equivalent restart/recovery.
3. Select reviewed beta infrastructure; rehearse backup/upgrade/restore; deploy
   and test the actual deletion Edge gateway, SMTP and deep links. None deployed.
4. Publish privacy/retention/support and consent information; staff ownerless
   recovery and incident/crash-reporting ownership; complete the private-beta
   checklist and exact-head CI review before any distribution.
5. Whole exports/memberships/balances/personal JSON still materialize in memory.
   Profile device/network behavior and large-group balance cost before size limits.
6. Receipt storage remains absent: local Storage is disabled and no reviewed
   private bucket/object policies exist. Recurrence uses the allowed robust
   template fallback only. No schedules, localization, full offline sync,
   push/email, analytics, bank/payment integrations or currency conversion.

The functional code is ready for review and later presentation design. Public
beta/store readiness is not claimed. PR8 remains draft and unmerged.

## Changed-file manifest

[Every path changed from master](changed-files.txt) includes both sprints,
source/tests, all forward migrations, tooling/CI and handoff documentation.
Generated from `git diff --name-only` plus nonignored new files; it is the full
inventory rather than a hand-selected screen list. Use
`git diff --stat 9fe698836488288fac704801f13683d3844bf4cc..HEAD` for review size.
