# Secure guest claims

Guest participation is intentionally separate from registered-user invitations.
A guest starts without an account, while a guest claim connects that exact
existing guest identity to an account later.

For private beta, an active group owner or administrator must select one active
guest and request an account claim using the exact email they already know. The
request is shown only to the matching authenticated account, which must accept
or decline it in the app. There is no automatic name matching, email-like
display-name matching, or silent identity merge.

On acceptance, OweLoop updates only that guest row's nullable `user_id`. The
existing `group_members.id` stays the same, so expense allocations,
settlements, audit history, and balances retain their durable financial links.
The operation cannot assign a privileged role.

Claims expire after 14 days and cannot be accepted after expiry, revocation,
decline, or prior acceptance. A guest and a target account can each have only
one open request in a group. Archived groups, removed guests, already-linked
guests, and users with an existing active membership are all rejected.

The claim table has no direct mobile-client access. Narrow, authenticated
database functions bind initiator and recipient identity to `auth.uid()` and
enforce group isolation. Any future discovery or notification feature needs a
separate privacy and abuse-prevention design.
