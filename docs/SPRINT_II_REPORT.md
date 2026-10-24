# Sprint II engineering record

Historical functional sprint evidence through `c56b433`. The subsequent
developer-onboarding pass is recorded separately in [HANDOFF](../HANDOFF.md).

2026-10-25, Australia/Sydney. Continued `codex/functional-completion` from clean,
synchronized `280b86dd9f67a1fecd25de97c185d9febd856ceb`. Base master remains
`9fe698836488288fac704801f13683d3844bf4cc`. Draft [PR8](https://github.com/lorenzodarioben-lgtm/OweLoop/pull/8)
is unmerged. No hosted deployment, release or production-data change occurred.
The five first-sprint commits and twenty existing migrations remain unchanged.

## Delivered scope

Audited owner reopen and trusted ownerless recovery resolve the archived-balance
lifecycle dead end without weakening deletion/financial guards. Optional immutable
categories propagate through creation, detail, duplicate, drafts, templates,
filtered history and exports. Settlement filters run server-side before stable
oldest/newest paging. Complete ledger exports now use one SQL snapshot including
exact allocations and names. CSV/personal JSON sharing has private account files,
explicit MIME, cancellation/error/expiry cleanup and account-switch checks.

Group templates save validated configuration and support optimistic creator/admin
editing/deletion. Review resets the date, filters inactive participants and clears
an inactive payer. Save/review never posts or retains an operation ID. This is the
assignment's robust-template fallback; recurrence schedules are not implemented.
A private activity inbox derives only currently authorized records, with stable
pages, unread filter, caller read state, refresh and links. Device default
currency and confirmed draft/export cleanup are reachable in Account and preserve
pending/unknown operations. Existing Material styling remains plain.

Local Storage is disabled and there is no reviewed private receipt bucket or
object policy/test setup. Receipts are not implemented or represented by inert
controls. Localization, push/email and full offline synchronization remain absent.
Offline scope is explicit unsent drafts, retained uncertain requests and manual
recovery. Reads can become stale; server validation remains authoritative.

## Commits and verification

| Commit | Coherent checkpoint |
| --- | --- |
| `52e1414` | Archive lifecycle recovery and categories |
| `aacdf4a` | Settlement filters, consistent exports/private sharing and templates |
| `60b12af` | Expanded native multi-account/real-process recovery harness |
| `0072953` | Correct native empty-state selector; run both independent probes |
| `ba81a51` | Private inbox, safe device settings and cleanup race correction |
| `806fdef` | Real Dart POST lookup correction, wire/live regressions, native async/Auth setup |
| `15a9f60` | Reproducible scale/live-SDK helpers, full manifest and combined handoff |

Resolve exact delivered HEAD with `git rev-parse HEAD`; final documentation/tooling
commits follow these code checkpoints. See [HANDOFF](../HANDOFF.md) for combined
architecture/setup/work queue and [the full inventory](changed-files.txt) for
every path changed across both sprints.

| Executed check | Result |
| --- | --- |
| Initial mobile baseline | 167 tests passed, clean analysis |
| Initial backend baseline | 303 pgTAP, 32 HTTP, six handler tests and 12+8 upgrade passed |
| Final Dart format | 175 files checked, zero changes |
| Final static analysis | No issues |
| Ordinary unit/widget suite | 186 passed, two live tests explicitly skipped without configuration |
| Real Dart SDK transport | Two live tests passed separately with loopback Auth/PostgREST |
| Final pgTAP | 404 assertions across 14 files passed |
| Schema lint | No errors/findings |
| Handler tests | Six passed |
| Three-account HTTP journey | 44 assertions passed |
| Fresh initialization | All26 migrations passed |
| Non-empty upgrade | 20+6 migrations passed, nine ledger snapshots and canonical balances preserved |
| Scale fixtures | All four passed and rolled back; see [performance](performance.md) |
| Android native runtime | One native UI/multi-account test and four real-process checkpoints passed on API35 |

The last full local command sequence was `dart format --output=none
--set-exit-if-changed .`, `flutter analyze --no-pub`, `flutter test --no-pub`,
then `scripts/check-local.ps1 -SkipInstall -DartIntegration`. The benchmark ran
separately through `scripts/check-local.ps1 -SkipInstall -Benchmark`. The Windows
Flutter wrapper was bypassed with the installed SDK's cached tool snapshot where
necessary; SDK/cache writes required execution outside the filesystem sandbox.
Every disposable stack was stopped. No skipped native/live test is counted as a
pass. Keys remained in process environment and raw operation data was not logged.

The HTTP journey adds category replay/conflict, unauthorized void, export/void
concurrency, exact allocations, settlement filters, template optimistic conflict,
concurrent reopen and actual Admin deletion followed by trusted ownerless recovery.
pgTAP adds adversarial direct grants/roles, NULL template creator permissions,
inbox removal/recipient/deletion privacy and multi-page tied-date cursors. Widget
coverage includes template review/save, reachable notification reads, archive
reopen, default-currency loading race, deletion blockers and local cleanup.

## Runtime findings and CI

Mobile analysis/tests and Android debug compilation, plus the database workflow,
passed on `806fdef09e72aa41ca7616dfcae18544171dc9bc`:
[Mobile CI](https://github.com/lorenzodarioben-lgtm/OweLoop/actions/runs/40118381705),
[Database CI](https://github.com/lorenzodarioben-lgtm/OweLoop/actions/runs/40118381667).
Final documentation/tooling-head checks follow this code checkpoint and are
recorded in the PR. Actions now use maintained Node24 versions and pinned
Ubuntu24.04; Flutter remains 3.44.2 / Dart 3.12.2. Native CI is separate and bounded.

The `15a9f606ed0d572e85febe3c3006286eaf3269a9` tooling/handoff checkpoint also
passed [Mobile CI](https://github.com/lorenzodarioben-lgtm/OweLoop/actions/runs/40118889697)
and [Database CI](https://github.com/lorenzodarioben-lgtm/OweLoop/actions/runs/40118889597).

The first real Android run compiled/installed the APK, then failed a stale empty
state selector. Subsequent runs reached Group details but attempted Add guest
before asynchronous authorization data arrived. The test now waits for controls,
guest completion and post navigation, with bounded checks. Independent B/C test
clients now configure implicit Auth signup because they do not provide Flutter
PKCE storage; production Auth configuration is unchanged.

The [third native run](https://github.com/lorenzodarioben-lgtm/OweLoop/actions/runs/40116934624)
reached the actual persisted-before-HTTP barrier, was force-stopped/relaunched,
and failed resume-before. A separate real Dart SDK test reproduced PGRST116/406:
`.maybeSingle()` on the POST operation lookup coerced zero rows to a server error.
The adapter now validates ordinary table JSON, returns null for zero rows and
rejects malformed/multiple rows. Four wire regressions and both real-SDK tests
pass. Lookup absence remains uncertain; it never becomes a rejected transaction.
The corrected [native run](https://github.com/lorenzodarioben-lgtm/OweLoop/actions/runs/40118377624)
at `806fdef09e72aa41ca7616dfcae18544171dc9bc` passed. The log records
`1 test passed` for the native UI/independent multi-account journey, then
`PASS: before`, `PASS: resume-before`, `PASS: after`, `PASS: resume-after`, and
the final real Android termination/secure-store/same-ID recovery PASS. Actual
session/storage reload and exactly one expense were checked after both force
stops. The later tooling/handoff checkpoint changes no mobile/native/harness
source, so this evidence applies to its identical app code. Sanitized
stage/type/code markers remain available for future diagnosis.

The probe is a separate debug target, not the release entry point. The host script
refuses physical devices, preserves app data, terminates the actual OS process
before send and after real SQL commit, reloads session/secure storage, retries the
original ID only if absent and checks exactly one unchanged expense. Reconstructed
controllers/fake stores are not counted as real-process evidence. See
[native testing](native-recovery-testing.md) for exact commands and limits.

Local Windows JDK21/IPv4 Gradle still fails before compilation with
`Unable to establish loopback connection`; no AVD/device is configured. Global
firewall/security settings were untouched. Native CI supplies an API35 emulator;
physical hardware, Keychain/iOS, callbacks, share-destination import, accessibility,
release signing and hosted deletion/SMTP remain external validation gates.

## New migrations

All six are forward-only, applied on fresh local PostgreSQL 17 and through the
non-empty twenty-migration upgrade. Existing values/rows and canonical balances
are compared; newly added category values are checked null on old expenses.

| Filename | Tables/functions and authorization | Operational consideration |
| --- | --- | --- |
| `20261025000000_audited_group_recovery.sql` | Lifecycle events, private reopen guard; owner-only `reopen_group`, locked `archive_group`, service-role-only `recover_ownerless_archived_group`, actionable deletion blockers | Reopen preserves financial history; operator identity/consent/support procedure required; client guard/DML access denied |
| `20261025010000_expense_categories.sql` | Nullable checked immutable category; guarded `create_categorized_expense`, private allocation helper, categorized history; old RPC unchanged | Fingerprint includes key; duplicate allocation validation must stay aligned; helper execution denied to clients |
| `20261025020000_filtered_settlement_history.sql` | Guarded filtered keyset settlement RPC with date/member/amount/state/direction checks | Cursors require all tuple values and matching filters; historical API retained |
| `20261025030000_consistent_ledger_exports.sql` | Authorized STABLE scalar expense/settlement snapshots including names/allocations | Complete reads avoid API row caps but materialize in memory; no streaming job |
| `20261025040000_expense_templates.sql` | RLS configuration table, validation, list/save/delete RPCs, creator/admin optimistic edits; no direct DML | 20 KB bound, case-insensitive name uniqueness, archived read-only, deleted creator NULL never grants authority; no schedules |
| `20261025050000_private_notification_inbox.sql` | Private read markers, guarded current-source paging/mark-read; wrapper personal export adds readable templates/caller markers | Source queries recheck membership/recipient, private helpers/internal export execution revoked, Auth cascades private markers only; audit-source scale needs profiling |

ADRs 0012-0014 record authority, persistence and dependency decisions. No new
hosted service was provisioned. Apply migrations only after a separately approved
beta backup/upgrade rehearsal; local validation does not authorize deployment.

## Known limits and next action

Fetch/confirm the delivered branch and exact PR checks first. The emulator run
passed; next complete physical Android/iOS and hosted lifecycle/recovery checks.
[HANDOFF](../HANDOFF.md) prioritizes files, commands and verification. Whole
snapshots remain memory-bound and large-group balance validation is the largest
measured SQL cost. The neutral design handoff maps the implemented screens;
financial identity, uncertainty, permission and template-review contracts are
stable design boundaries. Do not redesign away unresolved pending states or
claim beta readiness until native/hosted/operational gates are recorded.
