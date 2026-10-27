# Functional reference for the design phase

Sprint III adds `/groups/:groupId/schedules`, reachable as Recurring drafts from
group details. Create schedule from a template; set name, cadence, calendar anchor
and IANA zone. The list shows next dates, pinned template, enabled/cancelled state,
edit/pause/cancel, paged due history, explicit skip and completed expense links.
Review opens Add expense with due date/pinned fields and current-member filtering.
It requires Post expense and cannot detach the occurrence through draft/template
actions. Refresh failures identify stale data and disable mutations until retry.
Month ends clamp; discovery omits ungenerated dates older than 90 days, stated in UI.

For setup and the prioritized next task, start at [START_HERE](../START_HERE.md)
and [the roadmap](roadmap.md). This document remains the neutral functional
reference; it does not authorize a visual redesign or check off release gates.

This describes behavior and contracts, not a visual direction. Presentation can
be rebuilt without changing financial calculations, repository boundaries or
authorization. No color, typography, animation or branding choices are required
by this handoff.

## Navigation and screens

`mobile/lib/app/router.dart` owns GoRouter. `/` is the protected group-list root;
`/home` redirects there. Child routes build a predictable root/group/form stack.
Sign-out removes protected content. Authentication redirect states are loading,
signed out, verification pending, profile setup, password recovery and signed in.

| Route | Functional contents |
| --- | --- |
| `/loading` | Session/profile restoration progress. |
| `/sign-in`, `/sign-up` | Email/password entry, validation, submission progress and safe errors. |
| `/verify-email` | Pending verification, resend and return/sign-out controls. |
| `/forgot-password` | Email submission with generic account-existence feedback. |
| `/auth/callback`, `/update-password` | Verification/recovery callback and explicit password update. |
| `/profile-setup` | Required display name before shared-data access. |
| `/` | Groups, create group, collaboration inboxes, account/recovery menu and sign-out. |
| `/account` | Display-name edit, personal JSON copy/share, default currency, confirmed local draft/export cleanup, deletion blockers and password confirmation. |
| `/notifications` | Private activity inbox, manual refresh, stable pages, unread filter, read markers and links to authorized source records. |
| `/pending-submissions` | Account-scoped saved requests; check status or explicitly retry original payload. |
| `/invitations`, `/guest-claims` | Incoming requests, expiry, accept/decline and retry states. |
| `/groups/new` | Name and supported single currency. |
| `/groups/:groupId` | Members, guests, balances, repayment suggestions, recent history, collaboration, exports and safe leave. |
| `/groups/:groupId/settings` | Rename/archive, owner-only audited reopen, lifecycle history, safe removal, roles and ownership transfer. |
| `/groups/:groupId/templates` | Review, update and delete reusable configurations with creator/admin permissions. Review opens the existing expense form and never posts automatically. |
| `/groups/:groupId/expenses/new` | Description, optional category, date, total, one/multiple payers, equal/exact/percentage/share allocation; preview, draft and save-template controls. |
| `/groups/:groupId/expenses` | Full lazy paged history; description search, category, date range, participant and void filters. |
| `/groups/:groupId/expenses/:expenseId` | Immutable amount/allocations, status, safe audit events, authorized void and duplicate for correction. |
| `/groups/:groupId/settlements/new` | Two distinct members, amount, date and confirmation of an external payment. |
| `/groups/:groupId/settlements` | Full lazy paged history; date/payer/receiver/amount/void/order filters, details and authorized void confirmation. |
| `/groups/:groupId/exports` | Single-snapshot complete expense/settlement CSV with allocation JSON, explicit copy and private native file sharing. |

## Primary journeys

Register and verify as configured, complete a profile, create a group, add a
guest or invite a registered user, then record an expense. Preview exact final
allocations before submit. On confirmation, refresh balances/history. A repayment
suggestion prefills settlement entry; it never moves money or writes by itself.
Voiding and duplicating creates a reviewed correction while retaining history.

Guest claiming is two-party: an owner/admin targets a guest and known email;
the recipient explicitly accepts and receives that same durable membership.
Unknown addresses receive generic sender feedback and an unbound request.
Revoke/resend after later registration. There is no email delivery or public
identity search.

If a financial response is interrupted, show uncertainty and direct the user
to Pending submissions. Check status against the server or retry the saved
request. Navigation/restart must not generate a different identity for an
unresolved action. Unsent drafts are separate: explicit Save/Restore/Discard
does not submit a financial operation. Draft restoration filters inactive members.

Deletion first displays ownership/balance blockers, then requires password
confirmation and explains retained shared history. It needs a configured trusted
Edge function. A positive local UI state is not evidence that hosted deployment
or device secure storage has been validated.

## State behavior

Every data screen needs loading, unavailable/error with retry, empty and ready
states. History additionally needs incremental loading, load-more failure and
end-of-list states; changing filters resets the cursor. Existing records may
remain visible during refresh. Never replace a failed full export with partial
success. Account switches must clear or discard stale protected results.

Disable duplicate submissions while a request is active. Expense/settlement
creation succeeds only after authoritative confirmation. Pending/unknown,
confirmed and rejected outcomes must remain distinguishable. A missing operation
lookup does not establish rejection. Do not silently retry in the background.

Archived groups remain readable; normal mutation controls are unavailable.
A live owner can explicitly confirm Reopen group in settings, producing an
immutable event. An ownerless group explains the support recovery path; the
app cannot appoint a new owner. Removed
users lose access. Creator/admin authority controls voiding; owner/admin controls
are different, and guests cannot hold privileged roles. Client visibility helps
usability; the database independently enforces every permission.

## Reusable boundaries

Feature directories separate domain, repositories, state and presentation.
`ExactMoney`, `MoneyMath`, `SplitAllocationCalculator`, `DebtSimplifier` and
`LedgerCsv` are domain logic; keep financial math there. Production repositories
call guarded RPCs. `PendingFinancialOperations` owns durable request identities
and manual reconciliation. `ExpenseDraftStore` owns separate encrypted unsent
state. Riverpod wires dependencies; controllers handle stale responses and
refresh. History repository capabilities expose pages/cursors. Account operations
use `AccountRepository`; service-role credentials never enter Flutter.

Categories are stable optional keys; correcting a posted category uses
void/duplicate. Templates are shared configuration with optimistic edits;
review resets the date, removes inactive participants and clears an inactive
payer so the user must choose. No recurrence scheduler or automatic posting
exists. Device currency defaults cannot override a user's manual selection.

ExportSharing owns UTF-8 private files, MIME, cancellation, cleanup and account
switch checks. A successful share sheet is not evidence of destination import.
Local cleanup must preserve pending/unknown submissions. Inbox read markers
belong to the signed-in user and never grant access to source records.

Existing form fields, loading/error widgets, balance rows, history sections and
member selectors can be reused or replaced. Styling must not change which
request is retried, which record is voided, or which durable member is selected.

## Accessibility and financial clarity

Keep visible labels, semantic controls, readable validation and retry actions,
keyboard-safe forms, usable text scaling and focus order. Explain direction:
positive balance means owed money; negative means owes. Show currency and exact
amounts, participant names, transaction date and void state. Confirmation must
identify the financial action and its consequences. Never use color alone to
convey status. Screen-reader and large-text checks on actual devices remain
unexecuted; include them before distribution.
