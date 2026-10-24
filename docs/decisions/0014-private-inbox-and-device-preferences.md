# 0014: Derived private activity and account-scoped device preferences

- Status: Accepted
- Date: 2026-10-25

The notification inbox projects existing posted/voided expense events, external
settlement records, group lifecycle events and pending recipient-bound invitations/
claims. It never creates a second financial ledger or background posting system.
Stable prefixed source IDs provide idempotency. Every page rechecks current
membership or the exact invitation/claim recipient, and uses an `(at,key)` cursor.
Removal hides financial details immediately. Unknown-email requests remain
unbound and do not generate recipient activity or registration discovery.

Only caller-scoped read markers are stored. Guarded mark-read validates a
currently readable source and uses a unique account/key constraint. Direct
client table access and private projection-helper execution are revoked. Auth
deletion cascades only the user's private markers, preserving shared source
events. Personal export includes caller read state and currently readable
templates. Notifications link to authoritative existing screens. Refresh is
manual; no push, email or polling service is configured.

Default group currency is stored in the existing secure device storage under
an account namespace. It is not synchronized. Group creation consumes it only
before the user chooses a currency; delayed preference reads cannot override a
manual selection. Clearing drafts or cached export files requires confirmation
and never touches pending financial operations. Draft-key cleanup copies its key
list before deletion, avoiding live-map mutation. Currency and cleanup failures
remain explicit and retryable. No cosmetic preference or inert setting is added.
