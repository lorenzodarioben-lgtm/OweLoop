# Reproducible validation

Use Flutter 3.44.2 / Dart 3.12.2 (the CI-pinned SDK), Node 22, and Docker Desktop's
local Linux engine. Use only public development URL/anon values in `mobile/.env`.
The Supabase CLI remains project local; do not link routine tests to hosted data.

## Windows: full disposable backend check

```powershell
.\scripts\check-local.ps1
```

The script installs locked npm dependencies, creates a unique temporary Supabase
project, uses API port 60421 and DB port 60422, initializes all migrations, runs
pgTAP and lint, runs the deletion-handler tests, replays a non-empty baseline
upgrade, and performs the real three-account HTTP journey. It stops and discards
only its own stack. Existing local project volumes and hosted environments are
not reset. Select another free port block with `-PortBase 61420` if necessary.
Disposable configuration folders remain under the system temporary directory
for inspection; they are not repository artifacts.

The regular developer stack still uses `npm run db:start` / `npm run check:db` /
`npm run db:stop`. Windows can reserve port 55422; the isolated helper avoids
changing the checked-in project configuration to accommodate one workstation.

## Mobile checks

```powershell
cd mobile
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
```

No release keystore is required for the debug smoke build. A release build must
use the ignored signing configuration and must never fall back to a debug key.
On this workstation Gradle failed before compilation while establishing its
loopback connection; Android command-line tools/licence status also need repair.
Treat that as an unavailable native-build result, not a passing build.

## Individual backend and component checks

```powershell
npm ci
npm run db:start
npm run check:db
npm run test:account-function
```

For the real HTTP integration script, supply `SUPABASE_URL` and
`SUPABASE_ANON_KEY` from `npx supabase status -o json` to the test process. The
optional `SUPABASE_SERVICE_ROLE_KEY` is **local test-process only**, never Flutter
configuration. The isolated helper supplies it without printing it. The HTTP
script refuses every non-loopback endpoint. `npm run test:upgrade` accepts an
`OWELOOP_DB_CONTAINER` override, checks that Docker is local, and creates/drops
only a unique `oweloop_upgrade_*` database. Its Auth fixture is a minimal shim;
real Auth is covered separately by the HTTP journey.

## Native integration test: configured device required

```powershell
cd mobile
flutter test integration_test/private_beta_journey_test.dart -d <device-id> --dart-define=OWELOOP_TEST_SUPABASE_URL=http://10.0.2.2:60421 --dart-define=OWELOOP_TEST_ANON_KEY=<local-public-anon-key>
```

Android emulators use `10.0.2.2` for the host; iOS simulators can use loopback.
Use a disposable stack with local email confirmations disabled. The test now
registers a disposable account, uses the real repositories/secure storage, and
exercises group/guest/expense entry, exact balances, history and back navigation.
It is skipped when test URL/key are absent, and refuses hosted endpoints. It was
not executed on a native device during this sprint. The separate Node journey
covers the multi-account and concurrent backend scenarios without a device.

Physical restart, Keychain/Keystore behavior, TalkBack/VoiceOver, email callbacks,
release signing and macOS/Xcode builds remain explicit release gates. No widget
or service test substitutes for those checks.
