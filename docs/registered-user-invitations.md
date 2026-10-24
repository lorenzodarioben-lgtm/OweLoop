# Registered-user invitations

Private-beta group invitations are delivered inside OweLoop. They do not send
transactional email and do not create a public directory of OweLoop accounts.

An active group owner or administrator enters the exact email address they
already know for another person. The app gives generic submission feedback;
it does not tell the sender whether that address is registered, already a
member, or has an existing invitation. A matching registered user sees the
invitation in their own in-app inbox and may accept or decline it.

Only active owners and administrators can view their group's pending
invitations or revoke them. The recipient is derived from the authenticated
session at acceptance time. Acceptance can create only a normal `member`
membership, never an administrator or owner membership.

Invitations expire after 14 days. Expired, declined, revoked, and accepted
invitations cannot be reused. Archived groups cannot create, revoke, or accept
invitations. The underlying invitation table is not directly readable or
writable by ordinary mobile clients; narrow database functions enforce the
permissions and lifecycle.

This is intentionally a controlled-beta workflow. A future notification or
identity-discovery feature needs its own privacy, abuse-prevention, and email
delivery design; it must not expose account-existence lookup to ordinary users.

Unknown addresses retain an unbound sender request so list cardinality does not
reveal account registration. Such a request is not delivered or auto-bound after
signup. Revoke and resend once the recipient has registered. Acceptance always
checks an already bound recipient UUID, never a caller-supplied email identity.
