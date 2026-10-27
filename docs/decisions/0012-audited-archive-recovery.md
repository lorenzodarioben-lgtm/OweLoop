# 0012: Audited archive recovery

- Status: Accepted
- Date: 2026-10-25

An archive is reversible by its active registered owner. Reopening takes the
same group lock as posting, archiving and account deletion; it changes no
financial records or member roles. Repeated reopening of an active group is
idempotent. Admins, ordinary members, removed users and anonymous callers cannot
reopen. Direct group writes remain revoked. A private transaction guard permits
only the archived timestamp transition and is removed before returning.

Ownerless archives require a trusted operator, not a mobile override. The
service-role-only recovery RPC accepts an existing active registered/onboarded
member as successor and a recorded reason. It refuses active groups, archives
with a live owner, outsiders and inactive successors. It atomically reopens,
assigns that successor and appends an audit event. Operators must establish
consent/identity and retain their support case reference in the reason without
unnecessary personal data. This operation is not deployed or invoked on hosted
data during development.

Archive, reopen and operator recovery append RLS-protected lifecycle events.
Clients can read the most recent fifty in Group settings and cannot fabricate
or remove events. Account deletion retains events while nulling Auth references.
Outstanding archived balances now have an actionable owner-reopen path; if the
owner was deleted, support has a concrete audited recovery operation. No balance
is forgiven and ordinary settlement/ownership deletion prerequisites still apply.
