# Security model

Sprint III schedules/occurrences have current-membership RLS and guarded RPC-only
mutations. Creator/admin versioned edits, bounded server-calendar discovery and
atomic occurrence/expense posting retain ordinary persist-before-send recovery.
Pauses, cancellation, archive and removal prevent fresh posting; matching completed
replay returns the existing authorized result. No scheduler can post by itself.
See [ADR 0015](decisions/0015-bounded-review-only-recurrence.md).

The Flutter client is untrusted. It receives a public Supabase URL/key and a
user session. Service-role keys, database passwords and signing material never
belong in Flutter or source control. Guests are durable group records, not
anonymous API principals.

## Database boundary

RLS protects application tables. Grants deliberately narrow the RLS surface:

| Data | Ordinary authenticated access |
| --- | --- |
| Profiles | Caller reads their own; guarded completion/edit RPC writes only caller. |
| Groups/members | Active membership reads; validated RPCs own administrative changes. |
| Expenses/payers/splits/settlements | Active membership reads; guarded RPCs own mutations. |
| Expense events | Read through accessible expense; trusted triggers alone write. |
| Financial operations | No direct access; caller-only minimal reconciliation RPC. |
| Invitations/guest claims | No direct access; role-scoped sender and recipient RPCs. |
| Private deletion guards | No client privileges or public API exposure. |

Direct table and column UPDATE grants cannot bypass removal, archive, ownership
or financial validation. Legacy unchecked financial overloads are not callable
by clients. Public functions derive identity from `auth.uid()`, use fixed
`pg_catalog` search paths and qualified objects, and check current group state.
Private helpers remain in `app_private` with narrow execution grants.

Owners/admins must be active registered members. Guests cannot become admins.
Only an owner can transfer ownership or change privileged roles. Removal/leave
requires zero balance; an owner must first transfer. Group locks serialize those
checks with financial writes. Archive preserves readable history and blocks
financial/membership mutations. Composite FKs reject cross-group participants.

## Financial integrity and recovery

Posting validates positive amounts, exact totals, current membership and
immutable history. Numeric/BigInt intermediates and checked bigint boundaries
prevent overflow. Balance reads validate expense totals and zero sum. Settlements
record reported payments; OweLoop does not verify them or move money. Repayment
suggestions never create records automatically.

Creation requests bind a UUID to caller, operation type and server fingerprint.
Concurrent retries return the original result; different payloads are rejected.
Mobile persists before sending, scoped by account, and retains unknown outcomes
across restarts. Only explicit retry resends the saved request. Lookup absence
does not mean failure.

Pending requests and explicit unsent drafts use flutter_secure_storage in
separate account keyspaces. No Auth credentials are added to those records.
Actual Android emulator process termination/session/secure-store recovery passed
before send and after commit. Physical Keychain/Keystore and backup tests remain open.
Android backup is disabled; iOS entitlements are configured but not device-built.
Auth/data controllers discard stale account/session responses. Token refresh
preserves recovery sessions. Protected routes redirect after sign-out. These
client protections complement database authorization.

## Collaboration and privacy

Invitations/claims bind explicit acceptance to a known recipient UUID. Unknown
emails retain unbound sender records, closing sender-list registration discovery.
Later registration does not auto-bind them. Group membership itself is visible
to administrators. There is no public directory or email notification.

Personal export returns the caller's private data and readable shared ledgers.
CSV quotes values and neutralizes spreadsheet formulas; monetary fields stay
integer text. Exports require explicit copy/share. Files use account-scoped
private temporary directories, explicit MIME, a 20 MiB cap, cancellation/error
cleanup and 24-hour expiry on the next share. Account changes block sharing
the prior account's document. Destination-app import needs device verification.

Template configuration is group-readable, creator/admin-writable and validated
against current same-group members; it has no posting authority. Posted category
metadata is immutable. Notification source access is reevaluated on every page
and mark-read call; markers are private and cascade with Auth deletion. Unknown
emails do not become discoverable through the inbox. Local draft/export cleanup
does not delete pending/unknown operations.

Reopen requires the current live owner. Ownerless archived recovery requires a
service-role-only function, an existing active registered successor and a
recorded reason. Client callers have no access to transaction guard tables,
unchecked allocation helpers or internal export helpers. These recovery paths
never erase debt or alter immutable financial history.

The trusted deletion handler validates the bearer session online, reauthenticates
the server-verified email/password, checks blockers and invokes Admin deletion
for that exact verified user. Caller target IDs are ignored. Database guards
also enforce prerequisites and de-identify memberships, so old JWTs lose group
access. Shared descriptions, amounts and audit snapshots remain. See
[account lifecycle](account-lifecycle.md). Technical retention is not a published
privacy policy. Hosted Edge deployment has not been performed.

## Evidence and remaining boundaries

Local pgTAP tests unauthorized DML, owner/admin/member/outsider/anonymous roles,
removed access, idempotency, invariants and deletion. Real local Auth/PostgREST
exercises concurrent requests and actual Admin deletion. Handler tests cover
malformed input, authentication, blockers, verified target and safe failures.
Executed counts are in [the completion report](FUNCTIONAL_COMPLETION_REPORT.md).

Hosted rate limiting, abuse response, SMTP, support/privacy notices, backup
recovery, crash reporting and native secure storage/callback testing remain
operational decisions or release gates. No production security certification,
hosted deployment or payment verification is claimed.
