# Functional completion report

Date: 2026-10-24. Branch: `codex/functional-completion`. Base:
`9fe698836488288fac704801f13683d3844bf4cc` (`master`, merged PR #7).
Engineering checkpoint: `283cb79b40450bfd5d7a2c920ae7a5b1ca9e83ea`.
Draft review: [PR #8](https://github.com/lorenzodarioben-lgtm/OweLoop/pull/8).
Documentation commits follow that checkpoint; use `git rev-parse HEAD` for the
checkout's exact delivery revision. No production deployment or release occurred.

## Outcome and inventory

The starting repository already implemented the Version 0.1 shared-expense
core; it was not merely an application skeleton. The sprint preserves those
features and addresses financial permission bypasses, allocation correctness,
overflow, transient request IDs, stale async state, navigation and truncation.
New interfaces use standard Material controls. This is substantially stronger
application code, with explicit native/hosted release gates still open.

| Area | Final implementation | Evidence / qualification |
| --- | --- | --- |
| Exact money | Checked parsing, BigInt intermediates, native bigint-compatible bounds | Boundary tests for eight currencies; no floating-point allocation |
| Split modes | Equal, exact, percentage, weighted shares; zero weights remain zero | Deterministic Hamilton remainder tests and 500 generated allocations |
| Database permissions | Direct group/member column and financial writes revoked; guarded RPCs | Adversarial pgTAP, including the removal bypass |
| Financial posting | Atomic validated posting, immutable history, safe void/duplicate | Database invariants, concurrent HTTP idempotency replay |
| Balances/repayments | Canonical zero-sum read; aggregate-before-join optimization; deterministic suggestions | pgTAP plus real-service balance checks; no payment processing |
| Durable submissions | Persist-before-send encrypted account store, manual status/retry, payload matching | Lost-response/restart, storage-failure, double-submit and account-scope tests |
| Authentication | Existing email flows plus generation guards, recovery preservation and profile editing | Auth/widget race tests; native email callbacks not executed |
| Routing | Nested root/group routes with coherent form/back behavior | Widget navigation journeys; Android system back still needs device testing |
| Groups | Atomic creation, guest entry, rename/archive, roles/ownership, settled removal/leave | Real HTTP create and leave; role/archive/ownership pgTAP |
| Invitations/claims | Explicit recipient acceptance, generic sender records for unknown emails | Concurrent acceptance and privacy regressions; no email notifications |
| Expense history | Keyset pages, lazy list, description/date/member/void filters | 1,105-record equal-date traversal without duplicate IDs; stale-page tests |
| Settlement history | Keyset pages, details and authorized void | Existing settlement tests plus cursor validation; no filtering UI |
| Complete reads | Scalar snapshots for memberships, groups, balances and safe activity | 1,107-member snapshots and real PostgREST snapshot assertions |
| Drafts | Explicit secure Save/Restore/Discard, account/group scope | Widget restoration without RPC and isolation tests; no full offline sync |
| Ledger export | Complete paged expense and settlement CSV, formula protection | Pure CSV and widget tests; copyable text, no native sharing |
| Personal export | Caller-only JSON with monetary decimal strings | Account UI, pgTAP and real-service export checks |
| Account deletion | Password-confirmed trusted handler; database de-identification guards | Real local Admin deletion, retained history and old-JWT denial; hosted Edge gateway unverified |
| CI/tooling | Pinned Flutter, Android debug job, pgTAP/lint, handler/upgrade/HTTP checks | Local equivalents executed; remote run results recorded separately |
| Native readiness | Android backup disabled, iOS Keychain entitlements, configured real native test | Android debug APK built in CI; local build blocked; iOS/device tests unexecuted |

## Verification executed

All automated backend work used disposable local PostgreSQL/Supabase, never a
hosted reset. `scripts/check-local.ps1 -SkipInstall` completed successfully and
stopped its uniquely named stack. Earlier `npm ci` succeeded with zero reported
vulnerabilities. Public development keys were confined to process environment;
no local privileged key was printed into the handoff or committed.

| Check | Actual result |
| --- | --- |
| Dart format | 156 Dart files formatted; final changed files conform |
| Flutter analyze | No issues found (final local run: 25.9 seconds) |
| Flutter unit/widget tests | 167 passed, zero failures (final local run: about 49 seconds) |
| pgTAP | 303 assertions across 8 files, PASS (8 seconds) |
| Schema lint | No schema errors found; no lint findings |
| Trusted deletion handler | 6 Node tests passed, zero skipped/failures |
| Real local HTTP integration | 32 assertions passed with real Auth/PostgREST and three disposable accounts |
| Fresh migrations | All 20 migrations applied to a new disposable Supabase PostgreSQL 17 stack |
| Non-empty upgrade | 12 released + 8 forward migrations; 9 table snapshots and canonical balances preserved |
| Large synthetic balance read | 1,105 expenses / 1,107 members: 574.431 ms in one local timing diagnostic |
| Diff/secrets review | No whitespace errors after cleanup; targeted credential-pattern and sensitive-file review |
| Android local debug build | Attempted twice; failed before compilation: `java.io.IOException: Unable to establish loopback connection` |
| Android CI debug build | PASS on Ubuntu/JDK17; produced `build/app/outputs/flutter-apk/app-debug.apk` |
| iOS build/runtime | Not executed: no macOS/Xcode on this Windows host |
| Native integration test | Implemented/configuration-gated; not executed on a device |

The earlier balance query was cancelled after more than 158 seconds on the same
synthetic fixture. The new query preserves canonical validation and aggregates
before joining members. The 574 ms observation is not a production performance
guarantee. Large-group UI memory/scrolling and concurrent export snapshots still
need broader testing.

GitHub also independently passed the Flutter format/analyze/test and Android
debug jobs in [Mobile CI](https://github.com/lorenzodarioben-lgtm/OweLoop/actions/runs/40094829981),
and every backend step in [Database CI](https://github.com/lorenzodarioben-lgtm/OweLoop/actions/runs/40094829985)
at engineering checkpoint `283cb79b40450bfd5d7a2c920ae7a5b1ca9e83ea`.
The debug APK build succeeded; no APK installation or release signing is implied.
Final handoff and conservative retry revisions trigger their own PR checks; inspect PR #8
for the exact current-head result before merging.

## Failure injection and security evidence

- Fake transport commits then loses its response; a reconstructed service reads
  the saved operation, reconciles it or retries the same ID without a second
  financial record. Missing lookup remains uncertain. Storage failure sends no
  request. Changed payload and another account cannot reuse unresolved work.
  Adapter regressions also verify damaged success/proxy exceptions remain
  unknown and that an explicitly rejected retry cannot erase an earlier
  committed-but-unknown outcome. Only known SQL rollback codes on a first
  attempt allow rejection; permanently unavailable uncertain actions may need
  support review rather than silently unlocking a new request.
- Auth tests delay restoration/profile responses across sign-out/account change
  and preserve legitimate password recovery through token/user events.
- Real local HTTP sends five simultaneous expense retries, four settlement
  retries and duplicate invitation/claim acceptance. Assertions verify one
  durable result, conflicting-payload rejection and correct balances.
- pgTAP attempts forbidden direct mutations, foreign/removed participation,
  unauthorized reads, archived changes, unsafe owner/balance deletion and
  cross-account operation inspection. Legacy trigger tests use temporary fixture
  grants inside rollback-only transactions; production denial is tested separately.
- Deleting a verified local account with a different target ID in the request
  still deletes only the verified caller. Shared records survive; another user
  remains and the old token loses access. Handler transport tests also cover
  malformed bodies, wrong passwords, blockers and Admin API failure.

These do not simulate physical process termination, Keychain loss, device network
handoff, hosted JWT gateways, SMTP or restore-from-backup. No claim substitutes
widget/service tests for those missing checks.

## Changes and decisions

ADRs 0009-0011 record largest-remainder semantics, monetary bounds, maintained
secure-storage dependency, persist-before-send recovery, pagination and account
retention. The eight new migrations are forward-only: guarded mutations,
cursor history, atomic group creation, account lifecycle, deletion audit/locking,
complete snapshots, collaboration privacy and aggregate balances. None of the
twelve released migration files was edited.

The sole new direct mobile dependency is `flutter_secure_storage` 11.2.0. It
backs pending operations and explicit drafts, not full offline sync. Server
credentials remain outside Flutter. Pending records keep every unresolved
request and the latest thirty outcomes. A single unresolved request per account/
group/type prevents modified submissions from bypassing recovery.

## Remaining work and release decision

1. **Release blocker:** run the local native integration test plus physical
   restart/secure-storage/back/link checks using the CI-built Android code.
   Repair this host's Gradle loopback and missing Android command-line tools/
   licences; a passing remote debug build does not replace runtime tests.
2. **Release blocker:** on macOS build iOS and validate Keychain entitlement,
   signing, callback and VoiceOver behavior. Configure only reviewed beta
   infrastructure, SMTP and the deletion Edge function; verify the real gateway.
3. **Release blocker:** establish privacy/retention notice, support contact,
   backup/recovery rehearsal, incident owner, crash-reporting decision, signing
   and tester consent. None was invented, deployed or published here.
4. **Functional limitation:** archived nonzero-balance groups cannot be settled
   or unarchived in the app and block account deletion. Operator review is
   required; design a safe documented workflow before wider deletion use.
5. **Scale/portability:** whole membership/safe activity/personal export snapshots
   load into memory. CSV spans multiple requests, not a transaction snapshot;
   concurrent inserts/voids can require refresh/re-export. Native file sharing,
   settlement filters and very large-group UI performance remain improvements.
6. **Collaboration limitation:** unknown-email requests stay unbound. Revoke and
   resend after registration. No email/push notification or identity directory.
7. **Missing secondary features:** categories, receipts/storage policies,
   recurring expenses, preferences beyond profile, localization, notifications,
   analytics and full offline synchronization. These were left absent rather
   than introducing unverified storage/financial behavior during integrity work.

The code is ready for review and a presentation design phase against these
contracts. It is not verified for public beta or store distribution. First
complete native/runtime and hosted lifecycle validation; keep the PR draft.

## Changed-file manifest

The list below covers every path changed from the master baseline, including
new source, tests, migrations, CI and handoff documentation. It is generated
from Git, not a list of only the most visible screens.

```text
.github/workflows/database-ci.yml
.github/workflows/mobile-ci.yml
AGENTS.md
CONTRIBUTING.md
docs/account-lifecycle.md
docs/android-private-beta.md
docs/architecture.md
docs/database-design.md
docs/decisions/0009-exact-allocation-and-native-money-range.md
docs/decisions/0010-durable-financial-submissions.md
docs/decisions/0011-history-and-account-lifecycle.md
docs/decisions/README.md
docs/DESIGN_HANDOFF.md
docs/development-setup.md
docs/FUNCTIONAL_COMPLETION_REPORT.md
docs/hosted-beta-environments.md
docs/private-beta-operations.md
docs/private-beta-release-checklist.md
docs/private-beta-test-plan.md
docs/registered-user-invitations.md
docs/roadmap.md
docs/secure-guest-claims.md
docs/security-model.md
docs/testing.md
HANDOFF.md
mobile/android/app/src/main/AndroidManifest.xml
mobile/integration_test/private_beta_journey_test.dart
mobile/ios/Runner.xcodeproj/project.pbxproj
mobile/ios/Runner/Runner.entitlements
mobile/lib/app/router.dart
mobile/lib/core/operations/financial_operations_providers.dart
mobile/lib/core/operations/history_page.dart
mobile/lib/core/operations/pending_financial_operations.dart
mobile/lib/core/operations/pending_operations_screen.dart
mobile/lib/features/activity/data/supabase_expense_activity_repository.dart
mobile/lib/features/authentication/data/account_repository.dart
mobile/lib/features/authentication/presentation/account_screen.dart
mobile/lib/features/authentication/state/authentication_controller.dart
mobile/lib/features/balances/data/supabase_balances_repository.dart
mobile/lib/features/balances/state/balances_controller.dart
mobile/lib/features/expenses/data/expense_draft_store.dart
mobile/lib/features/expenses/data/expenses_repository.dart
mobile/lib/features/expenses/data/supabase_expenses_repository.dart
mobile/lib/features/expenses/domain/exact_money.dart
mobile/lib/features/expenses/domain/expense_models.dart
mobile/lib/features/expenses/domain/ledger_csv.dart
mobile/lib/features/expenses/errors/expenses_error_mapper.dart
mobile/lib/features/expenses/presentation/add_expense_screen.dart
mobile/lib/features/expenses/presentation/expense_history_screen.dart
mobile/lib/features/expenses/presentation/expense_history_section.dart
mobile/lib/features/expenses/state/expenses_controller.dart
mobile/lib/features/expenses/state/expenses_providers.dart
mobile/lib/features/expenses/state/expenses_state.dart
mobile/lib/features/groups/data/groups_repository.dart
mobile/lib/features/groups/data/supabase_groups_repository.dart
mobile/lib/features/groups/errors/groups_error_mapper.dart
mobile/lib/features/groups/presentation/group_detail_screen.dart
mobile/lib/features/groups/presentation/group_export_screen.dart
mobile/lib/features/groups/presentation/group_list_screen.dart
mobile/lib/features/groups/state/group_data_refresh_coordinator.dart
mobile/lib/features/groups/state/groups_controller.dart
mobile/lib/features/groups/state/groups_providers.dart
mobile/lib/features/guest_claims/presentation/group_guest_claims_section.dart
mobile/lib/features/invitations/presentation/group_invitations_section.dart
mobile/lib/features/repayments/domain/repayment_suggestion_models.dart
mobile/lib/features/settlements/data/settlements_repository.dart
mobile/lib/features/settlements/data/supabase_settlements_repository.dart
mobile/lib/features/settlements/errors/settlements_error_mapper.dart
mobile/lib/features/settlements/presentation/record_settlement_screen.dart
mobile/lib/features/settlements/presentation/settlement_history_screen.dart
mobile/lib/features/settlements/presentation/settlement_history_section.dart
mobile/lib/features/settlements/state/settlements_controller.dart
mobile/lib/features/settlements/state/settlements_providers.dart
mobile/lib/features/settlements/state/settlements_state.dart
mobile/pubspec.lock
mobile/pubspec.yaml
mobile/test/core/operations/pending_financial_operations_test.dart
mobile/test/core/operations/pending_operations_screen_test.dart
mobile/test/fakes/authentication_fakes.dart
mobile/test/fakes/expense_drafts_fakes.dart
mobile/test/fakes/groups_fakes.dart
mobile/test/features/authentication/account_screen_test.dart
mobile/test/features/authentication/authentication_races_test.dart
mobile/test/features/expenses/expense_models_and_money_test.dart
mobile/test/features/expenses/expense_screens_test.dart
mobile/test/features/expenses/financial_invariants_test.dart
mobile/test/features/expenses/history_pagination_test.dart
mobile/test/features/expenses/ledger_csv_test.dart
mobile/test/features/groups/group_screens_test.dart
package.json
PRODUCT.md
README.md
scripts/check-local.ps1
scripts/delete-account.test.mjs
scripts/test-local-integration.mjs
scripts/test-migration-upgrade.mjs
supabase/config.toml
supabase/functions/delete-account/handler.mjs
supabase/functions/delete-account/index.ts
supabase/migrations/20261024000000_guarded_mutations_and_reconciliation.sql
supabase/migrations/20261024010000_cursor_financial_history.sql
supabase/migrations/20261024020000_atomic_group_creation.sql
supabase/migrations/20261024030000_account_lifecycle.sql
supabase/migrations/20261024040000_deletion_audit_and_group_locking.sql
supabase/migrations/20261024050000_complete_read_snapshots.sql
supabase/migrations/20261024060000_non_oracular_collaboration_requests.sql
supabase/migrations/20261024070000_aggregate_balance_reads.sql
supabase/tests/database/001_core_database_foundation.sql
supabase/tests/database/003_registered_group_invitations.pgtap.sql
supabase/tests/database/005_guarded_mutations.pgtap.sql
supabase/tests/database/006_cursor_history.pgtap.sql
supabase/tests/database/007_account_lifecycle.pgtap.sql
supabase/tests/database/008_collaboration_privacy.pgtap.sql
```
