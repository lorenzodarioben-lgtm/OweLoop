# Private beta operations

## Monitoring and crash reporting decision

No crash-reporting vendor SDK is installed yet. That is intentional: a vendor,
data-processing terms, project ownership, DSN/configuration, and privacy
notice must be chosen before any telemetry is emitted. The integration
boundary should collect only operational diagnostics needed to reproduce a
failure; it must never include passwords, auth/refresh tokens, service keys,
or complete sensitive financial payloads.

Before inviting testers, choose a provider (for example Sentry or Firebase
Crashlytics), document the retained fields and retention period, add the
provider's configuration outside source control, verify symbol/source-map
handling, and test opt-out/support handling. Until then, tester support must
collect a timestamp, app version, device/OS, route/action, and a redacted
description only.

## Backup and recovery ownership

Use two named operators for beta data:

- **Primary operator:** configures the beta project, initiates backups, and
  performs a reviewed migration.
- **Recovery operator:** can independently access the project/backup location,
  verifies restore instructions, and approves destructive recovery actions.

Before each hosted migration and at a regular agreed cadence, confirm a backup
exists, its timestamp/location is recorded, and both operators can access the
restore procedure. Test restoration only in a separate rehearsal project.

If beta data is corrupted or a migration incident occurs, pause writes where
possible, preserve logs and timestamps, notify affected testers, restore or
roll forward only with both operators' approval, and record the outcome.

## Tester support and data expectations

These values are deliberately placeholders and must be chosen before any
external invitation:

| Item | Required value before beta | Current value |
| --- | --- | --- |
| Support contact | Monitored support email or approved contact channel | **Unconfigured** |
| Privacy notice | Hosted URL describing Supabase/auth/financial-data processing | **Unconfigured** |
| Feedback channel | Private issue form, email, or survey with triage owner | **Unconfigured** |
| Beta disclaimer | Clear statement that beta data may change and the app never moves money | **Unconfigured** |
| Deletion/data-retention process | Human-reviewed account/data request process and retention window | **Unconfigured** |

Do not promise account deletion, data export, backups, or a public support SLA
until the corresponding process is implemented and staffed. Testers should be
told not to use OweLoop as their sole financial record and not to enter
unnecessary sensitive personal data.

The functional sprint implements export and a trusted account-deletion component;
see [account lifecycle](account-lifecycle.md). Hosted deployment, published
retention terms and a staffed exception/support process remain unconfigured.
Live owners can reopen archived groups through audited Group settings, then
record external settlements before deletion. Ownerless archives require a
staffed, service-role-only recovery procedure to an existing active registered
successor; no client override or debt forgiveness exists. See ADR 0012 and the
account lifecycle runbook. That support process is still unconfigured.
