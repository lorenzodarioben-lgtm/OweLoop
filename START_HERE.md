# Start here

OweLoop is an Android/iOS shared-expense ledger for roommates, couples, students
and travellers. Create a group, add registered people or account-free guests,
record who paid and owes each expense, then record settlements made elsewhere.
**OweLoop records money; it does not move it.** Flutter/Dart, Riverpod and GoRouter
provide the app; Supabase Auth/PostgreSQL provide the backend.

## Use the handover branch

[Repository](https://github.com/lorenzodarioben-lgtm/OweLoop) ·
[draft PR #8](https://github.com/lorenzodarioben-lgtm/OweLoop/pull/8).
The functional baseline is **`codex/functional-completion`**, still unmerged into
`master`. Start here until PR #8 is reviewed/merged. Keep your own work on a new
branch, with PR base `codex/functional-completion` while that remains unmerged.

## Fastest safe start: PowerShell

Install **Git, Flutter 3.44.2 (Dart 3.12.2), Node 22/npm and Docker Desktop**.
Use Docker's local Linux engine. For Android, install Android Studio/SDK 36,
command-line tools, accept licences and start an emulator; CI uses JDK 17 and an
API 35 emulator. No Android device is required for unit/backend tests. iOS needs
macOS/Xcode. See [platform setup and troubleshooting](docs/development-setup.md).

```powershell
git clone --branch codex/functional-completion --single-branch https://github.com/lorenzodarioben-lgtm/OweLoop.git
cd OweLoop
git status --short
npm.cmd ci
npm.cmd run dev:check
npm.cmd run dev:start -- --configure-mobile
cd mobile
flutter pub get
flutter doctor -v
flutter devices
flutter run
```

`dev:start` creates a separate, per-checkout **local** backend in ignored
`.local-dev/`, applies migrations on first start and leaves it running. Host API
is `http://127.0.0.1:61421`; the generated ignored `mobile/.env` uses Android's
`10.0.2.2:61421` and only the public anon key. No key copying is needed. It refuses
remote Docker and preserves any existing `.env` instead of replacing credentials.
First image download can take several minutes. Sign up with a disposable local
email/password and complete a display name; local email confirmation is disabled.
The hosted deletion Edge function is not configured by this setup.

From a second terminal at the repository root:

```powershell
.\scripts\check.ps1
.\scripts\check-local.ps1 -SkipInstall -DartIntegration
npm.cmd run dev:status
# When finished with the app backend:
npm.cmd run dev:stop
```

The full backend check uses its own API 60421/DB 60422 project and stops only that
test stack. It can coexist with app development on API 61421/DB 61422. `dev:stop`
stops only this checkout's backend and retains local data; it deletes no user
files. No script installs global tools, links a hosted project or resets hosted
data. [Testing levels](docs/testing.md) explain cost, prerequisites and CI.

On macOS/Linux use `npm` instead of `npm.cmd`, `cp` instead of `Copy-Item`, and
`./scripts/check.sh` for Flutter checks. For an iOS simulator use
`npm run dev:start -- --configure-mobile --client-host=127.0.0.1` on a fresh
checkout. The isolated backend check can run with PowerShell 7:
`pwsh -File scripts/check-local.ps1 -SkipInstall -DartIntegration`.
Physical phones need a deliberately configured reachable development endpoint;
`10.0.2.2` is emulator-only. Do not use production credentials to solve this.

## What you inherit

For optional receipt development on a **fresh checkout/configuration**, run
`npm.cmd run dev:start -- --storage --configure-mobile`, then from `mobile/`
`flutter run --dart-define=OWELOOP_RECEIPTS_ENABLED=true`. This enables only the
generated local Storage/Edge services; existing config/env files are preserved.
Use a separate checkout/port block if an existing local backend has other settings.
PNG/JPEG receipt controls stay hidden in ordinary builds until that capability
is deliberately enabled. [Receipt contract](docs/decisions/0016-private-receipt-gateway.md).

Sprint III extends this baseline with serialized financial recovery, actual
Android draft restart/isolation evidence and review-only recurring drafts.
Create a schedule from Expense templates, then open Recurring drafts from group
details. Server-calendar daily/weekly/fortnightly/monthly discovery never posts
automatically. Current migration/test counts and evidence are in
[Sprint III](docs/SPRINT_III_REPORT.md) and [HANDOFF](HANDOFF.md).

Working features include exact flexible/multi-payer expenses, immutable audit
and void/duplicate correction, balances, reported settlements, registered/guest
collaboration, guarded group administration and audited reopening, account
export/deletion components, secure submission recovery/drafts, categories,
reviewed templates, filtered history, consistent exports/private sharing,
activity inbox and device settings. UI uses plain Material controls intentionally;
visual design is a separate phase.

The functional checkpoint has 26 migrations, 186 passing unit/widget tests,
two separately passing live SDK tests, 404 pgTAP assertions, 44 real API assertions
and six handler tests. Android debug compilation and emulator UI/process-death
recovery passed. Dates, revisions and latest onboarding rehearsal are in
[HANDOFF.md](HANDOFF.md); [historical reports](docs/SPRINT_II_REPORT.md) retain the
original evidence. These results do not establish production readiness.

Physical Android, iOS/Keychain, destination sharing, callbacks/accessibility,
hosted deletion/SMTP, signing, backup/restore and staffed privacy/support processes
remain release gates. PDF/WebP receipts, localization, full
offline sync and push/email delivery are missing. Templates never post by
themselves. [Roadmap](docs/roadmap.md) separates local tasks from owner/hardware gates.

## Find the code

| Concern | Location |
| --- | --- |
| App entry, routes | `mobile/lib/main.dart`, `mobile/lib/app/router.dart` |
| Auth, groups, expenses, settlements | `mobile/lib/features/<feature>/` |
| Domain/repositories/providers/screens | Each feature's `domain/`, `data/`, `state/`, `presentation/` (some small features combine layers) |
| Exact money and splits | `mobile/lib/features/expenses/domain/` |
| Balances and repayment suggestions | `mobile/lib/features/balances/`, `mobile/lib/features/repayments/` |
| Durable operations/private export files | `mobile/lib/core/operations/` |
| Notifications | `mobile/lib/features/notifications/` |
| SQL schema/authorization/tests | `supabase/migrations/`, `supabase/tests/database/` |
| Trusted deletion | `supabase/functions/delete-account/` |
| Flutter/native tests | `mobile/test/`, `mobile/integration_test/` |
| Checks and CI | `scripts/`, `.github/workflows/` |

## First contribution and Claude Code

Read [AGENTS.md](AGENTS.md), then [CONTRIBUTING.md](CONTRIBUTING.md) for collaborator
and fork paths, identity, tests, commits and PR commands. The native unsent draft
restart task passed in Sprint III. Pick the current independent P1 task from
[the roadmap](docs/roadmap.md) and branch from the handover branch before editing.

Install/sign in to Claude Code using its [official quickstart](https://code.claude.com/docs/en/quickstart).
From the repository root run `claude`. Root [CLAUDE.md](CLAUDE.md) imports the shared
agent rules using [supported project memory](https://code.claude.com/docs/en/memory).
Use `/memory` to inspect loaded project instructions, then ask it to read
`START_HERE.md`, `HANDOFF.md` and the current roadmap P1 task before implementing.
The CLI/account are not installed or authenticated by this repository.

Essential references: [architecture](docs/architecture.md),
[financial/security boundaries](docs/security-model.md),
[database](docs/database-design.md), [ADRs](docs/decisions/README.md),
[neutral design handoff](docs/DESIGN_HANDOFF.md),
[release checklist](docs/private-beta-release-checklist.md).
