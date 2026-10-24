# Private beta release checklist

Complete and record every applicable item before distributing a build.

## Hosted service

- [ ] A separate beta Supabase project is selected and independently verified.
- [ ] Ordered migrations are applied and migration state rechecked.
- [ ] Backup and recovery ownership is confirmed by two operators.
- [ ] Hosted Auth has the exact `oweloop://auth/callback` redirect URL.
- [ ] Email confirmation/reset behavior and the email provider are tested.
- [ ] Trusted `delete-account` Edge function is deployed on beta; passwords,
  blockers, actual deletion and old-token denial are verified there.
- [ ] Only public URL and anon key are in the build's ignored `.env`; no
  service-role credential is present.

## Build and devices

- [ ] Android SDK is installed and `flutter build apk --debug` succeeds.
- [ ] Secure release signing is configured outside source control and the
  signed release build is independently verified.
- [ ] Application name, version (`0.1.0+1` or reviewed successor), icon, and
  splash are reviewed on a physical Android device.
- [ ] Android deep links for verification and password recovery work on-device.
- [ ] Later, repeat the build/deep-link smoke test on iOS with macOS/Xcode.

## Product smoke test

- [ ] Complete every scenario in [the two-account test plan](private-beta-test-plan.md).
- [ ] Verify financial retry idempotency after an uncertain response.
- [ ] Verify archived history remains read-only.
- [ ] Reopen as live owner, reject member/admin reopen, and rehearse audited
  ownerless recovery with a trusted operator. Verify unchanged balances/history.
- [ ] Review template defaults after a participant leaves; save/update/delete
  without posting, then explicitly post with a fresh operation ID.
- [ ] Exercise category and settlement filters across multiple pages.
- [ ] Share CSV/JSON to real destinations and cancel shares on both platforms;
  check exact values, formula protection, private file cleanup and account switch.
- [ ] Verify private inbox/read state after removal and account switching;
  clear drafts/temporary exports without removing unknown submissions.
- [ ] Verify in-app invitations and explicit guest claims with separate users.
- [ ] Verify restart/session restoration and timeout/offline error feedback.
- [ ] Verify pending requests and drafts after physical process termination,
  restart and account switching, including platform secure storage.
- [ ] Verify personal/ledger export and published shared-record retention policy.
- [ ] Run physical accessibility smoke checks with increased text size and
  TalkBack/VoiceOver where available.

## Operational readiness

- [ ] Support contact, privacy notice, disclaimer, feedback route, and
  deletion/data-retention process are published to testers.
- [ ] Crash/error-reporting provider is selected or the manual support process
  is explicitly accepted for this limited beta.
- [ ] Tester list, consent/expectations, and incident contact are recorded.
- [ ] Release commit, migration list, environment, app build, device results,
  and known limitations are recorded in the release log.

## Repository validation

- [ ] Full backend checks pass for the release commit (`scripts/check-local.ps1`
  on Windows or the database CI workflow).
- [ ] `flutter pub get`, format check, `flutter analyze`, and `flutter test` pass.
- [ ] CI is green for the exact release commit.
- [ ] Secret/diff review confirms no `.env`, signing material, token, or
  service-role key is committed.

## Functional sprint evidence

Local results and limitations are recorded in
[the completion report](FUNCTIONAL_COMPLETION_REPORT.md). They do not check off
hosted setup, release-commit CI or device distribution. Release-specific items
above intentionally remain unverified until an operator records their results.
