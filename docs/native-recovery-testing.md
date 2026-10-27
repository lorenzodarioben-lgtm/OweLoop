# Native local journey and process-death recovery

Use a disposable local Supabase stack with email confirmations disabled. Never
pass a service-role key or hosted URL to Flutter. Android debug builds alone
permit cleartext local HTTP; release networking policy is unchanged.

## Native multi-account journey

```powershell
cd mobile
flutter test integration_test/private_beta_journey_test.dart -d emulator-5554 --dart-define=OWELOOP_TEST_SUPABASE_URL=http://10.0.2.2:55421 --dart-define=OWELOOP_TEST_ANON_KEY=<local-public-key>
```

The main account uses the real UI for group/guest/expense/back navigation.
Independent Supabase clients register the other accounts, accept invitations,
record a settlement, claim the durable guest, check exact multi-payer/non-equal
posting and reversal, filtered history, export snapshots, templates and archive/
reopen authorization. The app session is asserted unchanged by these clients.
It skips without local configuration. A skipped test is not runtime evidence.

## Real termination probe

This is a separate debug app target, never the release entry point:

```powershell
cd mobile
flutter build apk --debug -t integration_test/recovery_probe_app.dart --dart-define=OWELOOP_TEST_SUPABASE_URL=http://10.0.2.2:55421 --dart-define=OWELOOP_TEST_ANON_KEY=<local-public-key>
cd ..
node scripts/test-android-recovery.mjs emulator-5554
```

ADB must be on PATH. The host script refuses physical-device serials and checks
the emulator property. It installs the debug probe with data preserved, writes
a non-secret phase selector inside this app's private `files` directory, and
waits for sanitized checkpoints. It force-stops the actual OS process, not a
controller or widget, then starts the same installation again.

The before-send barrier occurs after the encrypted request is written but before
HTTP. The after-commit barrier occurs after real PostgREST success but before
the transport returns to the operation service. After restarting, the official
Auth session storage and Android secure storage must reload. Recovery checks
status or retries the original ID, checks persisted confirmation and asserts
exactly one unchanged expense in the disposable group. No passwords, sessions
or financial payloads are printed. The marker protocol times out rather than
retrying indefinitely. The script stops its probe app at completion and does
not remove unrelated apps or reset a shared backend.

## CI and limits

Sprint III adds `draft` / `resume-draft` after the four financial checkpoints.
The first saves exact/date/category/payer/participant configuration in the real
secure store; ADB preserves data and terminates the process. Resume checks all
fields and session reload, removes a zero-balance guest, applies the same review
logic as the form, verifies account B cannot read A's draft, and checks that
draft cleanup preserves an unresolved operation and creates zero expenses.
This debug probe exercises storage/domain actions; widget tests cover form actions.
`node --test scripts/native-checkpoint.test.mjs` deliberately withholds a marker
to prove bounded timeout and sanitized failure output.

`native-smoke.yml` runs on manual dispatch and pushes that change only the
native-test/harness paths, recovery operations/draft review source or migrations.
Ordinary presentation/source changes do not trigger
this heavier job. It uses a fresh local backend and API35 emulator on a pinned
Ubuntu runner, then stops the backend. Executed results are recorded in Sprint II;
adding this workflow does not itself establish a pass. It covers
Android emulator process termination, not physical Keystore hardware, backup/
restore, iOS, SMTP callback or hosted Edge deployment.

Executed PASS at `806fdef09e72aa41ca7616dfcae18544171dc9bc`:
[API35 native run](https://github.com/lorenzodarioben-lgtm/OweLoop/actions/runs/40118377624).
The UI/multi-account test passed and all four before/resume-before/after/
resume-after checkpoints passed. Earlier runs exposed selectors/async test setup
and the real Dart SDK absent-lookup mismatch, now covered by regressions.

The Windows host still has no configured AVD/device and its JDK21 Gradle attempt
failed at loopback initialization. No global firewall or security settings were
changed. Native run status and exact CI links belong in the Sprint II report.
