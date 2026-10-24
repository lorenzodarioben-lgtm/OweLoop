# OweLoop engineering handoff

## Sprint II continuation

Sprint II began from the clean first-sprint head `280b86d` on 2026-10-25.
Read [the Sprint II record](docs/SPRINT_II_REPORT.md) for current milestones and
new evidence; the first-sprint snapshot below remains historical context until
the combined final inventory is refreshed. Archive recovery and optional
categories are implemented. Settlement filters, consistent export snapshots,
private native sharing and reusable group templates are also implemented and
locally verified (175 Flutter tests; twenty-plus-five migration upgrade). Native
harness and further product work continue; see the Sprint II record for evidence.

## Repository state

- Repository: https://github.com/lorenzodarioben-lgtm/OweLoop
- Working branch: `codex/functional-completion`; base: `master` at
  `9fe698836488288fac704801f13683d3844bf4cc` (merged PR #7).
- Initial validated engineering checkpoint: `283cb79b40450bfd5d7a2c920ae7a5b1ca9e83ea`.
- Draft PR: https://github.com/lorenzodarioben-lgtm/OweLoop/pull/8.
- Implementation and tooling have been committed and pushed. Handoff work and a
  final conservative transport/retry correction follow the initial checkpoint.
  The intended delivered working tree is clean; no unfinished source files or
  secrets are intentionally left uncommitted.
- Resolve the exact final HEAD with `git rev-parse HEAD` or the PR head SHA.
  A tracked document cannot contain the hash of its own containing commit;
  the checkpoint above is explicit rather than claiming that self-reference.

Relevant commits: `b64d81d` guarded financial mutations/exact allocation;
`1158f0a` recoverable ledger/history/account lifecycle; `283cb79` reproducible
multi-account/upgrade tooling. Use `git log origin/master..HEAD --oneline` for
the handoff and final recovery correction as well. Git uses the human operator's existing
identity. No history was rewritten and no release, merge or production deployment
was performed.

## What changed

The starting Version 0.1 already included most shared-expense workflows. The
sprint closes direct membership-removal/administration bypasses; defines checked
money boundaries and Hamilton allocation; serializes financial mutations with
membership/role changes; and makes creation requests persist before sending.
Unknown network outcomes can now be checked or manually retried after restart
using the same payload/identity. Stale Auth/data responses cannot restore a
signed-out account. Nested routes provide root/group/form back behavior.

New reachable features: full cursor history, expense search/date/member/void
filters, explicit saved expense drafts, complete expense/settlement CSV export,
profile editing, personal JSON export, safe group leave and password-confirmed
account deletion through a trusted component. Account deletion de-identifies
members while preserving shared records; it requires settled balances and no
active group ownership. Group creation now works atomically through PostgREST.
Unknown-email collaboration requests no longer reveal registration through
sender-list cardinality. Complete scalar snapshots avoid API row truncation.
Balance aggregation was optimized after a large-fixture query exposed rescans.

The eight new `20261024*` migrations are forward-only; the twelve released SQL
files are untouched. ADRs 0009-0011 explain allocation, secure persistence,
history and retention. The [completion report](docs/FUNCTIONAL_COMPLETION_REPORT.md)
contains feature status, evidence and every changed path. The
[design handoff](docs/DESIGN_HANDOFF.md) maps screens and behavioral contracts.

## Architecture to preserve

Flutter lives in `mobile/`, with feature-owned domain/repository/state/presentation
code. Riverpod provides dependencies and controller lifetimes. Authentication
owns session generations; protected feature providers clear or invalidate stale
work on session change. Group refresh observes current notifier identities.
GoRouter roots at `/`; group forms/history/settings/exports are nested children.
`/home` is a compatibility redirect.

`ExactMoney`, `MoneyMath`, allocation and repayment domain logic are independent
of widgets. All money uses integer minor units and checked BigInt intermediates;
supported currencies are AUD/CAD/EUR/GBP/JPY/NZD/SGD/USD. Each group has one
currency. UI previews never replace SQL validation. Canonical balances are
derived from immutable posted allocations and nonvoided reported settlements.

Production repositories invoke narrow Supabase RPCs. SQL derives caller identity,
uses RLS/grants, stable group locks and validated exact totals. `group_members.id`
is the financial identity; claiming/removing/deleting an account does not replace
that ID. Guest users have no anonymous Auth access. Invitations and claims require
explicit known-recipient acceptance; unknown-email requests remain unbound.

`core/operations/PendingFinancialOperations` persists account-scoped payloads
through flutter_secure_storage before RPC submission. States: pending/unknown/
confirmed/rejected. All unresolved requests survive pruning; thirty recent
outcomes are retained. Timeout or absent lookup stays uncertain. Payload mismatch
blocks a new action for the same group/type until recovery. No background retry
loop exists. Unsent expense drafts use a separate encrypted keyspace and require
explicit restoration. Account switching cannot send another account's records.

Only a known SQL transaction rejection on the first attempt can mark it rejected.
Malformed success/proxy responses remain unknown; a rejected retry never clears
earlier uncertainty. If the original action is permanently unavailable, keep it
blocked for support review instead of manufacturing a fresh operation identity.

The deletion handler is in `supabase/functions/delete-account/`. It validates
Auth online, reauthenticates the verified email/current password and deletes that
exact user with a server-only credential. Database deletion guards independently
enforce zero balances/ownership and retain shared ledgers. See
[account lifecycle](docs/account-lifecycle.md); hosted gateway deployment remains
unverified. Do not add service credentials to Flutter.

## Setup and commands

Use Flutter 3.44.2 / Dart 3.12.2, Node 22 and Docker Desktop's local Linux engine.

```powershell
git clone https://github.com/lorenzodarioben-lgtm/OweLoop.git
cd OweLoop
git switch codex/functional-completion
git status --short
git rev-parse HEAD
npm ci
.\scripts\check-local.ps1
Copy-Item mobile/.env.example mobile/.env
cd mobile
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter run -d <device-id>
flutter build apk --debug
```

Edit the ignored `mobile/.env` with the development URL/public anon key only.
The isolated check creates a unique temporary project at API60421/DB60422,
applies migrations, tests, then stops/discards only itself. For interactive
development use `npm run db:start`, `npm run db:reset` on disposable local data,
`npm run check:db`, `npm run db:stop`. Never link routine validation to a hosted
project. Windows reserved port55422 blocked the regular stack on this host;
use the isolated helper or documented free-port configuration, not a hosted reset.
The helper stops its stack, so start a local development stack before running
the app. Android emulator URLs use `10.0.2.2` to reach the host.

Individual checks: `npm run test:account-function`, `npm run test:upgrade`,
`npm run test:integration`. The last two need a running local stack/configuration;
[testing.md](docs/testing.md) documents process-local keys and container selection.
No credentials are hard-coded. The configured native integration command is:

```powershell
cd mobile
flutter test integration_test/private_beta_journey_test.dart -d <device-id> --dart-define=OWELOOP_TEST_SUPABASE_URL=http://10.0.2.2:60421 --dart-define=OWELOOP_TEST_ANON_KEY=<local-public-key>
```

That test refuses hosted endpoints and skips without defines. It needs a running
disposable local stack with confirmations disabled. On macOS install Xcode,
resolve signing/Pods, then run `flutter build ios --no-codesign` and simulator/
physical-device tests; no iOS build has been executed on this Windows host.
Release signing and hosted setup are separate reviewed operations described in
the [release checklist](docs/private-beta-release-checklist.md) and
[hosted runbook](docs/hosted-beta-environments.md).

## Verified results and practical limits

Final local runs: 167 Flutter tests; clean analysis; formatted Dart; 303 pgTAP
assertions in eight files; clean schema lint; six Node handler tests; 32 real
Auth/PostgREST assertions; fresh twenty-migration initialization; non-empty
12+8 migration upgrade with nine snapshots and canonical balances preserved.
Synthetic 1,105-expense/1,107-member balance snapshot: 574.431 ms in one local run.
Tests covered concurrency, lost responses, account isolation, direct mutation
attempts, deletion/history preservation and old-token denial. Full details and
scope limits are in the completion report. These are not physical-device or
hosted deployment results.

Local Android debug builds were attempted twice and failed before compilation
with `java.io.IOException: Unable to establish loopback connection`. Android
SDK36 is installed; command-line tools are missing and licence status unresolved.
The independent [GitHub Mobile CI run](https://github.com/lorenzodarioben-lgtm/OweLoop/actions/runs/40094829981)
built the Android debug APK successfully on Ubuntu/JDK17 at `283cb79`.
The [database run](https://github.com/lorenzodarioben-lgtm/OweLoop/actions/runs/40094829985)
also passed every step. The remaining Android gate is device runtime/recovery,
not a claim that compilation has never succeeded.
There is no macOS/Xcode, attached native device, verified secure-storage restart,
SMTP callback or deployed Edge gateway evidence. Remote CI is available on PR #8;
check the exact current head before merging. Keep the draft until release gates
are satisfied.

## Priorities and known issues

1. **Release blocker:** verify Android runtime, persisted recovery
   after process termination, account switching, Android back and email links.
2. **Release blocker:** verify iOS build/Keychain/signing/links on macOS and run
   TalkBack/VoiceOver/large-text checks on physical devices.
3. **Release blocker:** configure reviewed beta SMTP/deletion function, test the
   Edge gateway, publish retention/privacy/support terms, rehearse backup restore
   and assign incident/release owners. No production deployment is authorized by
   this handoff itself.
4. **Functional:** archived groups with outstanding balances cannot settle or
   unarchive in-app; deletion remains blocked and needs operator review. Decide a
   safe lifecycle before enabling broad account deletion.
5. **Scale/portability:** large JSON membership/activity/personal-export snapshots
   consume memory; CSV is a multi-request read, so concurrent edits may require
   re-export. Native file sharing and settlement filtering remain absent.
6. **Product backlog:** categories, receipts, recurring expenses, notifications,
   localization, additional preferences and full offline synchronization are
   missing. Do not confuse saved drafts/pending recovery with offline sync.

Presentation work can proceed using the neutral design handoff. Keep exact money,
permission boundaries, explicit retry semantics and retained audit history intact.

**Next concrete action:** on a configured Android environment, run the local
native journey above and verify a
saved pending request across actual app termination before expanding features.
