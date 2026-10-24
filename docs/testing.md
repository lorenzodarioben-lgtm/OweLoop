# Reproducible testing

Run commands from the repository root unless a block says `cd mobile`.
Use Flutter 3.44.2/Dart 3.12.2, Node 22/npm and the project-local Supabase CLI.
[START_HERE](../START_HERE.md) installs locked dependencies and configures a
separate app backend. Routine tests never need a hosted account or production key.

| Level | Requires | Automatic CI |
| --- | --- | --- |
|1 Quick sanity | Flutter SDK; `flutter pub get`; `mobile/.env` exists (blank example is sufficient for unit tests) | Mobile CI checks format/analyze |
|2 Full Flutter | Same; no Docker/device | Mobile CI unit/widget tests |
|3 Backend | Node/npm, Docker local Linux; PowerShell on Windows or optional PowerShell 7 elsewhere | Database CI equivalent CLI steps |
|4 Native | Android SDK/JDK/device or emulator; local backend for runtime | Mobile CI debug build; separate native workflow for configured runtime |
|5 Release | Physical Android/iOS, macOS/Xcode, approved beta accounts/secrets/operators | Manual gates; not inferred from local CI |

## Level 1: fast checks

For documentation/setup instructions, `npm run check:docs` from root validates
tracked/new Markdown relative file targets without fetching external links.
It runs in Mobile CI too; heading fragments/external URL availability are outside
this file-existence check. Manually review commands and anchor destinations.

```powershell
cd mobile
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test test/features/expenses/expense_models_and_money_test.dart
```

Choose the actual feature test relevant to your change. `git diff --check` from
root catches whitespace errors. Plain documentation changes need link/command
validation; financial, authorization or persistence changes need deeper levels.

## Level 2: complete Flutter suite

```powershell
.\scripts\check.ps1
```

macOS/Linux: `./scripts/check.sh`. Both install Flutter dependencies, check
formatting, analyze and run `flutter test` in `mobile/`. Formatting may rewrite
nonconforming files before returning failure; review the diff and format
intentionally before committing. The suite includes Auth/domain/controller/widget
coverage. The two `test/live/financial_transport_test.dart` tests skip without
explicit loopback URL/anon environment; a skip is not a live pass.

A fresh checkout needs `mobile/.env` because it is a bundled Flutter asset. Use
`dev:start -- --configure-mobile` for app development, or copy the blank example
for unit-only work (`Copy-Item mobile/.env.example mobile/.env` on Windows,
`cp mobile/.env.example mobile/.env` elsewhere). Do not overwrite a real env file.

## Level 3: disposable backend/security/upgrade/API

Docker Linux running; from root:

```powershell
.\scripts\check-local.ps1 -DartIntegration
```

It runs `npm ci`, starts its own unique temporary project (API 60421/DB 60422),
initializes all 26 migrations, runs 404 pgTAP assertions/schema lint, six handler
tests, the non-empty 20+6 upgrade preserving nine table snapshots/balances, and 44
real Auth/PostgREST assertions with three accounts and actual Admin deletion.
`-DartIntegration` then runs two real Dart SDK adapter tests. Public/local service
keys remain test-process-only; no service role is written into Flutter config.
The helper restores environment and stops/discards only its own stack in `finally`.
Its temporary configuration/log folders may remain for diagnosis.

After locked dependencies are installed, `-SkipInstall` saves time. Optional
`-Benchmark` runs bounded rollback-only scale fixtures; [measurements](performance.md)
are not production/device guarantees. Override occupied ports with `-PortBase 63420`.
Run one helper at a time. Do not repurpose common environment variables.

On macOS/Linux the same helper supports PowerShell 7:

```sh
pwsh -File scripts/check-local.ps1 -DartIntegration
```

That platform invocation is supported by command selection but was not executed
on the Windows handover host. Without PowerShell, the standard root CLI commands
are `npm ci`, `npm run db:start`, `npm run check:db`,
`npm run test:account-function`, `npm run test:upgrade`, `npm run db:stop`.
They target the normal local project's ports 55421/55422. `check:db` resets that
local project; only use disposable data. The separate HTTP script requires
loopback `SUPABASE_URL`, local `SUPABASE_ANON_KEY` and optionally the local
`SUPABASE_SERVICE_ROLE_KEY` in its process environment; the PowerShell helper or
Database CI supplies these without manual copy. Upgrade accepts
`OWELOOP_DB_CONTAINER`, checks local Docker and creates/drops only its unique
`oweloop_upgrade_*` database. Never link routine checks to a hosted project.

## Level 4: Android compilation and native runtime

```powershell
cd mobile
flutter doctor -v
flutter devices
flutter build apk --debug
```

A debug build requires SDK/JDK, not a release key. Runtime tests additionally need
an actual emulator and the configured local backend. From root after `dev:start`:

```powershell
$localStatus = npx.cmd supabase status -o json --workdir .local-dev | ConvertFrom-Json
$anon = $localStatus.ANON_KEY
cd mobile
flutter test integration_test/private_beta_journey_test.dart -d emulator-5554 --dart-define=OWELOOP_TEST_SUPABASE_URL=http://10.0.2.2:61421 --dart-define=OWELOOP_TEST_ANON_KEY=$anon
flutter build apk --debug -t integration_test/recovery_probe_app.dart --dart-define=OWELOOP_TEST_SUPABASE_URL=http://10.0.2.2:61421 --dart-define=OWELOOP_TEST_ANON_KEY=$anon
cd ..
node scripts/test-android-recovery.mjs emulator-5554
Remove-Variable localStatus,anon
```

These commands use the default dev port; adjust it if you selected another block.
They register disposable accounts. Native tests refuse hosted endpoints; the
force-stop script refuses physical devices. It tests actual OS termination before
send/after SQL commit, session/secure-store reload and same-ID exactly-once recovery.
It does not yet cover unsent draft restoration. The separate debug probe must
never become the release target. See [native testing](native-recovery-testing.md)
for contract/CI details and Bash commands for CI's normal backend on 55421.

The native workflow runs on manual dispatch or changes to its harness paths; it
uses API 35/local Supabase on Ubuntu. Ordinary source changes do not rerun that
heavy workflow automatically. At the functional checkpoint the UI journey and
all four process checkpoints passed; exact evidence is in [Sprint II](SPRINT_II_REPORT.md).
The outgoing Windows host's Gradle loopback failure/no AVD remains a local build/
launch limitation, even though independent CI compiled and executed the app.

## Level 5: release validation

On macOS with configured Xcode, run `flutter doctor -v`, `flutter build ios --no-codesign`
and `flutter devices` from `mobile/`, then `flutter run` on the selected simulator/
device. Signing and physical Keychain/Keystore tests require platform setup and
credentials; do not invent passing results. Verify physical share destination/
cancellation, account switching, connectivity, callbacks, text scaling and
TalkBack/VoiceOver using the [multi-account plan](private-beta-test-plan.md).

Hosted work requires a deliberately approved beta target, operator access,
backup/restore rehearsal, SMTP/deep links and actual deletion Edge gateway tests.
Only follow the [hosted runbook](hosted-beta-environments.md) after owner approval.
Never run a hosted reset. Use the [release checklist](private-beta-release-checklist.md)
to record commit/build/device/environment/results and staffed privacy/support/
incident ownership. No script checks off these gates for you.

## Latest evidence

[HANDOFF](../HANDOFF.md) records the fresh-clone onboarding execution and any
skips/failures; [functional report](FUNCTIONAL_COMPLETION_REPORT.md) and
[Sprint II](SPRINT_II_REPORT.md) preserve earlier checkpoint evidence. Do not call
an inherited result a new local execution. Inspect exact-head CI on the PR.
