# OweLoop engineering handoff

Updated 2026-10-25, Australia/Sydney. New developers first open
[START_HERE.md](START_HERE.md); this is the authoritative continuity record.

## Final developer-onboarding pass

Started from clean/synchronized `c56b433385dae836401ca6236e75b7d811ce99b8`
(13 commits in draft PR #8, passing exact-head Mobile/Database CI). This pass adds
no product feature, financial change or migration. START_HERE is the setup hub;
CLAUDE.md imports AGENTS.md, which owns shared engineering contracts.
CONTRIBUTING documents collaborator/fork branches from the unmerged baseline.
The roadmap now separates a safe first engineering task from hardware/operator
release gates and optional product work. Historical reports/160-path manifest
remain checkpoint artifacts; current paths come from Git.

`npm run dev:check` diagnoses prerequisites without installing/modifying tools.
Explicit `dev:start -- --configure-mobile` creates a per-checkout local app
backend under ignored `.local-dev/` (API 61421/DB 61422), writes only a new public
mobile env and never overwrites credentials. `dev:stop` verifies the generated
project identity and stops only that backend, retaining data. The isolated full
test helper remains API 60421/DB 60422 and now selects Windows/POSIX commands;
PowerShell 7 on macOS/Linux is supported but not locally executed here.

Cold-start rehearsal uses a separate remote clone of the starting checkpoint,
overlaid only with proposed handover files. It began with no `.env`, node_modules
or `.dart_tool`; npm and Pub also installed with empty per-checkout caches.
The installed Flutter/Android tools and Docker image cache are shared host
prerequisites, not copied checkout state. Dependency install, local start/env
generation, clean analysis and 186 unit/widget tests passed (two live tests skip
without configuration). The rehearsal was executed, not inferred from CI:

| Commands/checks in the isolated checkout | Actual result |
| --- | --- |
| Remote branch clone; no env/dependencies/build state copied | Starting HEAD matched `c56b433`; only proposed handover files overlaid |
| `npm ci`, also `npm ci --cache .npm-cache`; `flutter pub get` with `PUB_CACHE` pointing at a new checkout-local `.pub-cache` | Passed from empty per-rehearsal package caches; no signing/config files copied |
| `npm run dev:check`, `npm run dev:start -- --configure-mobile`, `npm run dev:status` | Passed; fresh local backend/migrations and public env generated |
| Repeat start/configure; modified existing env; forged project ID/comment; unsupported host option | Identical setup preserved env; conflicts/foreign stop/unsupported host refused; no unrelated container stopped |
| Real HTTP integration against the generated app backend | 44 assertions passed, including actual local Auth/Admin deletion |
| `.\scripts\check.ps1` | Formatting/static analysis clean; 186 unit/widget tests passed, two explicitly configured live tests skipped |
| `.\scripts\check-local.ps1 -SkipInstall -DartIntegration` | Fresh 26 migrations; 404 pgTAP/14 files; clean schema lint; six handler tests; 20+6 upgrade/nine snapshots+balances; 44 HTTP assertions; two live Dart SDK tests passed |
| `flutter doctor -v`, `flutter devices`, `flutter run -d android` | Doctor reported missing Android command-line tools/licence validation; only desktop/web targets, no Android target; launch exited 1 |
| `flutter build apk --debug` | Failed before compilation with Gradle `Unable to establish loopback connection`; no host/global security changes or unbounded retries |
| Documentation checker and deliberate missing-file probe | All relative file targets passed; injected broken link correctly failed and probe removed; external URL availability/heading fragments not automatically checked |

The app rehearsal backend and isolated test backend were stopped individually;
only pre-existing unrelated Docker services remained. Temporary checkout/package
caches/logs remain in system temporary storage for diagnosis and are not delivery
files. No temporary branch needs merging. macOS/Linux PowerShell invocation,
iOS, physical hardware and Claude Code login were not executed here (Claude CLI
is not installed). Supported CLAUDE.md import/start behavior was checked against
[official memory docs](https://code.claude.com/docs/en/memory) and
[quickstart](https://code.claude.com/docs/en/quickstart). Exact pushed-head CI links
belong in PR #8's Developer Handover section; don't relabel inherited native
evidence as a new run. App/SQL/native harness sources remain unchanged.

Files in this pass: `START_HERE.md` (entry), `CLAUDE.md`/`AGENTS.md` (shared rules),
`CONTRIBUTING.md` (collaborator/fork workflow), `README.md` (discovery), this file
(continuity/evidence), `docs/development-setup.md`/`docs/testing.md` (commands and
levels), `docs/roadmap.md` (prioritized task contracts), `docs/DESIGN_HANDOFF.md`
(neutral reference link), `docs/private-beta-operations.md` (correct reopen
guidance), `docs/FUNCTIONAL_COMPLETION_REPORT.md`/`docs/SPRINT_II_REPORT.md`
(historical report banners/manifest explanation),
`scripts/dev-local.mjs` (local app setup), `scripts/check-doc-links.mjs` (file-link
validation), `scripts/check-local.ps1` (platform command selection), `package.json`
(script entry points), `.gitignore` (generated dev backend) and
`.github/workflows/mobile-ci.yml` (automatic link check). The 160-path manifest
is preserved as functional-sprint evidence; use Git for the full current diff.

## Delivery state

Repository: https://github.com/lorenzodarioben-lgtm/OweLoop
Branch: `codex/functional-completion`. Draft [PR #8](https://github.com/lorenzodarioben-lgtm/OweLoop/pull/8).
Master base: `9fe698836488288fac704801f13683d3844bf4cc`. Sprint II began from
`280b86dd9f67a1fecd25de97c185d9febd856ceb`, clean and synchronized with origin.
First-sprint commits and twenty migrations were preserved. Six forward migrations
bring the total to twenty-six. No merge, release, hosted deployment or production
mutation was performed. Git uses the operator's existing identity.

Latest pushed code checkpoint: `806fdef09e72aa41ca7616dfcae18544171dc9bc`.
The real Dart lookup correction and corrected Android emulator journey/process
recovery are verified. Final documentation follows that code checkpoint.
Resolve the exact delivered revision with `git rev-parse HEAD` and
`git rev-parse origin/codex/functional-completion`; a document cannot contain
the hash of its own containing commit. The final PR description records delivery
state. See [Sprint II evidence](docs/SPRINT_II_REPORT.md), the
[combined completion report](docs/FUNCTIONAL_COMPLETION_REPORT.md) and the
[design handoff](docs/DESIGN_HANDOFF.md). Visual design remains a separate phase.

Local-only ignored setup/build artifacts include `mobile/.env`, `.dart_tool`,
Flutter build output and `node_modules`. They are not delivery files or secret
handoff material; recreate dependencies and configure a new public development
URL/anon key. Disposable validation folders/logs remain in system temporary
storage; their uniquely named Docker stacks are stopped. No extra branch or
worktree needs merging or recovery.

## Working functionality

The starting repository already had the shared-expense core. Both sprints now
provide email/profile/recovery flows; durable registered/guest memberships;
explicit invitations and guest claims; guarded roles/ownership/removal/leave;
exact flexible expenses; immutable history and void/duplicate corrections;
canonical balances; external-payment settlements and repayment suggestions.
Checked BigInt intermediates prevent floating-point and overflow accounting.
Encrypted persist-before-send operations, explicit recovery, separate unsent
drafts, nested navigation and stale-response guards strengthen those journeys.
The trusted deletion component preserves shared history and rejects ownership
or unsettled-balance deletion. Hosted function operation remains unverified.

Sprint II adds complete reachable Material interfaces:

- Live owners can confirm audited Reopen group in settings. Ownerless archived
  recovery is a separate service-role-only operator function, to an existing
  active registered/onboarded member with a recorded reason. No debt is erased.
- Optional categories survive form, draft, duplicate, template, detail, history
  filter and CSV. Posted categories are immutable; old pending payloads/RPCs work.
- Settlement history filters date/payer/receiver/exact amount/void state/order,
  with stable keyset cursors. Full-list state is separate from group previews.
- Expense/settlement exports use complete single-statement SQL snapshots,
  including exact allocation JSON, names, categories and void state. Native
  CSV/personal JSON sharing uses private account files and explicit user actions.
- Group templates validate configuration, support optimistic creator/admin edits
  and delete, and prefill the existing form for explicit review/posting. Inactive
  participants are removed and an unavailable payer is cleared. No operation ID
  is saved. No scheduled recurrence or automatic financial posting exists.
- A private inbox projects currently authorized financial/lifecycle activity and
  recipient-bound pending invitations/claims. It has stable pages, unread filter,
  caller-only read markers, refresh and source links. Removal revokes access.
- Account/device settings store default currency and offer confirmed unsent-draft
  and temporary-export cleanup. Pending/unknown operations are preserved.

## Verification and environments

Last completed code-suite evidence: clean analysis; 186 Flutter tests plus two
explicitly skipped live tests in the ordinary run; both live tests separately
passed against disposable real Auth/PostgREST;
404 pgTAP assertions in fourteen files; six deletion-handler tests; 44 real
Auth/PostgREST assertions using three accounts; clean schema lint; fresh 26
migrations; non-empty twenty-plus-six upgrade preserving nine table snapshots
and canonical balances. Four real SDK wire-protocol regressions passed too.
Mobile/Android-debug and database CI passed at `806fdef`.

The native workflow compiled and installed a real Android APK. Its first runs
failed test selectors/async readiness, then reached the actual persist-before-send
barrier. Resume-before failed. A separate local real-SDK test reproduced the
cause: `.maybeSingle()` on a POST RPC throws PGRST116/406 for absent operations.
The adapter now reads/validates the table JSON result; malformed/ambiguous rows
stay uncertain. Live SDK and new wire regressions passed. The corrected
[API 35 emulator run](https://github.com/lorenzodarioben-lgtm/OweLoop/actions/runs/40118377624)
passed the UI/independent multi-account journey and all four actual-process
checkpoints: before, resume-before, after and resume-after. Session/secure-store
reload, same-ID recovery and exactly one unchanged expense passed after both
terminations. Native/app sources are identical at the later handoff commit.
Physical Keystore, iOS and destination-share results remain unverified.

The Windows host has Flutter 3.44.2/Dart 3.12.2, Node 22, Docker Desktop and SDK 36,
but no configured AVD or connected device. Two JDK 21 locations were inspected;
a process-local JDK 21/IPv4 Gradle attempt still fails before compilation with
`Unable to establish loopback connection`. No global security setting changed.
Android CI uses Ubuntu/JDK 17/API 35 emulator. There is no macOS/Xcode/iOS result.

Four rollback-only scale fixtures passed, up to 1,000 members/2,000 expenses/
1,000 settlements. First history page ~1.3ms and canonical balance ~1.7s at the
largest fixture are local SQL observations. See [performance](docs/performance.md)
for exact observations, outlier and memory limitations.

For a fresh checkout, follow [START_HERE](START_HERE.md). The app setup is:

```powershell
git clone --branch codex/functional-completion --single-branch https://github.com/lorenzodarioben-lgtm/OweLoop.git
cd OweLoop
npm.cmd ci
npm.cmd run dev:check
npm.cmd run dev:start -- --configure-mobile
cd mobile
flutter pub get
```

The helper writes a new ignored public URL/anon `mobile/.env`; Android
emulators reach the local host through `10.0.2.2:61421`. `flutter run -d <device-id>`
launches the app; `flutter build apk --debug` builds it when the host toolchain
works. Stop this app backend with `npm run dev:stop`. Release signing is
deliberately absent. Legacy normal-stack commands from root:
`npm run db:start`, `npm run db:reset`, `npm run db:test`, `npm run db:lint`,
`npm run db:stop`. Reset only a disposable local project. Upgrade validation is
`npm run test:upgrade` with a checked local `OWELOOP_DB_CONTAINER`; the helper
below supplies it and runs the full non-empty upgrade automatically.

```powershell
# Repository root; Docker running. Unique temporary stack, never hosted reset.
.\scripts\check-local.ps1 -SkipInstall
.\scripts\check-local.ps1 -SkipInstall -DartIntegration
.\scripts\check-local.ps1 -SkipInstall -Benchmark
# mobile/
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

`-DartIntegration` requires Flutter on PATH or `FLUTTER_ROOT`. Its two live tests
skip in ordinary unit runs unless a loopback URL/anon key is explicitly supplied.
The isolated helper uses API 60421/DB 60422, restores process environment and stops
only its own unique stack. The regular project uses API 55421/DB 55422; Windows can
reserve that DB port. Existing unrelated Docker services must remain untouched.
Native commands and force-stop semantics are in
[native recovery testing](docs/native-recovery-testing.md).

## Boundaries the next developer must preserve

Financial logic lives outside widgets. Group-member UUIDs are durable ledger
identities; claiming/deleting/removing accounts never replaces them. SQL uses
fixed search paths, current caller authority, RLS/grants, stable group locks and
validated exact totals. There is no mobile service-role credential or direct
financial DML escape hatch. Read snapshots avoid PostgREST row-cap truncation.

Pending operations are account-scoped encrypted saved payloads, written before
send. Keep every unresolved request and thirty recent outcomes. Status is
pending/unknown/confirmed/rejected. Absent lookup never proves rejection. Only an
explicit SQL rollback on the first attempt can reject; a rejected retry cannot
erase previous uncertainty. Never auto-generate an ID to bypass unresolved work
or silently retry in the background. Account switches cannot submit another
account's payload. Drafts and templates never carry financial operation IDs.

Owner reopen changes only archive state and appends an audit event; private
transaction guards are inaccessible to clients. Operator ownerless recovery
requires a staffed support procedure and consent/identity checks. Deletion
requires zero membership balances and no active group ownership. Reopen, settle,
transfer/archive, then delete. Preserve descriptions/financial audit snapshots;
this technical retention policy still needs a published privacy notice.

Sharing writes UTF-8 with explicit MIME to an account-private temporary folder,
rejects >20 MiB, deletes cancellation/error files and prunes files older than24 h on
next share. Successful/unknown handoffs retain files so the destination can read.
A share sheet result never proves import. Clear exports/drafts must not clear
unknown operations. Notification read markers never grant source access.

ADRs 0009-0014 record money, persistence, lifecycle, templates/export and inbox
contracts. `share_plus` 13.3.1 adds native sharing; direct `path_provider` 2.1.6 was
already transitive. `http` 1.6.0 is dev-only for real SDK wire regressions, already
transitive; no runtime package upgrade is implied.

## Remaining work in priority order

1. First action: fetch origin, run `git status --short`, confirm the branch/head
   and inspect PR #8 checks. Read the exact native result in the Sprint II record.
   The Android emulator journey/process-death run passed. Next verify physical
   Android Keystore, network-loss,
   back/callback, account-switch, draft restart, share destination/cancellation,
   large-text/TalkBack and release-signing checks. Emulator success is narrower.
2. On macOS build/run iOS, verify Keychain, share sheet/iPad origin, callbacks,
   signing, VoiceOver and equivalent process recovery. Windows cannot do this.
3. On deliberately selected beta infrastructure, rehearse backup/upgrade/restore,
   deploy/test the trusted deletion Edge gateway and configure SMTP/deep links.
   This assignment did not authorize deployment; do not reuse local credentials.
4. Staff ownerless recovery/support, publish privacy/retention/consent notices,
   establish incident ownership and crash-reporting decision, then complete the
   private-beta checklist before distribution. Keep PR #8 draft until reviewed.
5. Profile large-group UI/network/memory and balance validation; whole exports,
   memberships, balances and personal JSON still materialize in memory.
6. Optional scope: receipt attachments require a reviewed private Storage bucket,
   object policies, deletion/export integration and native file lifecycle; none
   exists. Recurrence uses the robust-template fallback only. No scheduled jobs,
   localization, full offline sync, push/email, analytics or payment integrations.

Unknown-email invitations/claims remain unbound: revoke/resend after signup.
There is no identity directory. Template removal/edit permissions remain SQL
controlled; shared templates from deleted creators are admin-maintainable.
No placeholder is counted as a finished feature.

## Single next action

After the fresh setup and `git fetch origin`, create the independent branch for
the [P1 native unsent-draft restart task](docs/roadmap.md) from a clean checkout:

```sh
git switch -c test/native-draft-restart origin/codex/functional-completion
```
