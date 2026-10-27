# Database design

Sprint III adds the 27th forward migration, `20261028000000_review_only_recurrence`.
`expense_schedules` pins template configuration and calendar/zone/revision;
`expense_occurrences` uniquely identifies schedule/calendar dates and links only
authoritatively confirmed expenses. RLS protects reads; direct DML is revoked.
All configuration/discovery/skip/post RPCs derive current caller authorization
and use fixed search paths/group locks. See [ADR 0015](decisions/0015-bounded-review-only-recurrence.md).
Personal export now includes currently readable schedules/occurrences.

PostgreSQL owns authorization, transaction boundaries and financial consistency.
The original twelve migrations remain unchanged. Eight forward migrations dated
`20261024` extend that baseline; six `20261025` migrations add Sprint II.
New environments apply all twenty-six in order. Released files are unchanged.

## Authoritative records

| Table | Meaning |
| --- | --- |
| `profiles` | Private Auth-linked name and explicit onboarding completion. |
| `groups` | One currency, creator and optional archive timestamp. |
| `group_members` | Durable registered or guest identity; role and removal state. |
| `expenses` | Exact amount, description, date, creator and draft/posted/voided state. |
| `expense_payers`, `expense_splits` | Exact contributions and obligations attached to durable members. |
| `settlements` | Reported external payments with immutable amount and optional void state. |
| `expense_events` | Append-only trigger-generated expense/allocation audit history. |
| `financial_operations` | Caller-bound request identity, fingerprint and committed result. |
| `group_invitations`, `guest_claim_requests` | Explicit, expiring collaboration requests. |

Composite foreign keys prevent cross-group financial references. Guest claiming,
removal and account de-identification preserve the same membership ID. Guests
have no Auth identity and no anonymous API access.

## Write contracts

Normal clients use authenticated RPCs. Direct group/member column updates and
financial DML are revoked, including legacy column-level grants. The public
surface includes profile completion, atomic group creation, guest entry,
rename/archive, removal/leave, roles/ownership, invitations/claims, expense
posting/voiding and settlement recording/voiding. Functions derive the caller
from `auth.uid()` and validate current state; RLS also protects readable tables.

`create_group(text,text)` validates onboarding, name and currency and creates
its owner atomically. The RPC avoids PostgREST INSERT RETURNING checking
membership before the owner-creation trigger becomes visible.

Normal flexible entry uses
`create_expense(uuid,text,bigint,timestamptz,jsonb,jsonb,uuid)`; the final UUID is
`p_operation_id`. `record_settlement(uuid,uuid,uuid,bigint,timestamptz,uuid)` also
requires that identity. Released unchecked overloads remain for migration
compatibility but are not executable by clients. Internal draft/finalization
steps happen in one transaction, never as a client write sequence.

An expense requires a positive total and payer allocations, nonnegative split
allocations, distinct active same-group participants, and exact payer/split sums.
The database validates final allocations independently of the UI split mode.
Posted financial rows are immutable. Correction uses void and a new reviewed
record; normal clients never hard-delete shared ledger history.

Financial posting, membership removal/leave and owner-role changes lock the
group before validating membership. Server operation IDs and fingerprints reject
payload reuse and serialize concurrent replay. `get_financial_operation(uuid)`
returns a minimal outcome only to its original caller, even after group removal.
An absent lookup does not prove an in-flight request failed.

## Money and balances

Amounts use PostgreSQL `bigint` minor units. Mobile supports JPY (zero decimals)
and AUD, CAD, EUR, GBP, NZD, SGD, USD (two). Unsupported display currencies fail
explicitly. There is no conversion. Positive individual amounts range from one
through 9,223,372,036,854,775,807 minor units. Dart uses BigInt intermediates;
database SUM uses numeric intermediates and checked bigint result casts.

Equal splits distribute remaining units by ascending durable member ID.
Percentage and weighted shares use Hamilton largest remainder: descending exact
fractional remainder, then ascending member ID. Zero weight receives zero.
See [ADR 0009](decisions/0009-exact-allocation-and-native-money-range.md).

The canonical balance is:

```text
posted payer amounts - posted split amounts
+ nonvoided settlement payments - nonvoided settlement receipts
```

Positive means owed; negative means owes. Draft/voided expenses and voided
settlements contribute nothing. Reads include active members at zero and
historical removed participants with financial history. They validate expense
totals and group zero sum, rejecting inconsistent or excessive aggregates.
The latest helper aggregates valid expense totals and member deltas before
joining memberships, avoiding repeated scans per participant.

## Complete reads and history

`get_expense_page` and `get_settlement_page` use descending financial date,
creation timestamp and ID cursors. Limits are 1-100 plus one lookahead row.
All three cursor values are required together. Expense description substring,
date, member and void-state filters apply before the limit. Clients deduplicate
boundaries and discard stale results when filters or sessions change.
History pages remain live views across requests. Ledger exports instead use
single-statement STABLE scalar JSON snapshots with exact allocations, names,
categories and void state; their consistency does not depend on page traversal.
Categorized expense history and settlement filters preserve legacy RPCs while
adding stable filter-aware cursors in both supported settlement directions.

Scalar JSON snapshots expose complete current groups, memberships, canonical
balances and safe expense activity beyond PostgREST's default row cap. These
prevent silent truncation but load the relevant set into memory. Safe activity
omits raw event JSON and authentication metadata.

## Collaboration and account lifecycle

Invitation/claim tables have no direct client access. Known recipient UUIDs
alone can read or accept. Unknown emails retain unbound sender records so
sender-list cardinality does not reveal registration. Revoke and resend after
later registration; no automatic email binding exists. Requests expire after
fourteen days and cannot elevate roles or mutate archived groups.

The database blocks Auth deletion while any membership balance is nonzero or
the account owns an active group. A trusted trigger locks affected groups in
stable order, de-identifies memberships and clears Auth-linked references while
preserving shared amounts, IDs and audit history. Its private transaction guard
cannot be set by clients and is removed after FK actions. See
[account lifecycle](account-lifecycle.md). Live owners can reopen archived groups
through an audited guarded RPC. Ownerless recovery requires a service-role-only
operator RPC, an existing active registered successor and a recorded reason.

## Sprint II configuration and private state

`expense_templates` contains validated group-scoped JSON configuration, never
financial records or saved operation IDs. Creator/admin edits use optimistic
timestamps; archived groups are read-only. Removed/inactive participants are
filtered on form review and SQL validates them again at posting.

`group_lifecycle_events` is append-only through guarded lifecycle functions.
`app_private.group_reopen_guards` is transaction-only and inaccessible to clients.
Expense category keys are optional and immutable after posting. Categorized
request fingerprints include the key; existing uncategorized payloads/RPCs work.

`notification_reads` has RLS, no direct client table access and an Auth cascade
for private read markers. Inbox functions project current authorized financial,
lifecycle and recipient-bound collaboration sources. Removed members immediately
lose source access; unknown emails remain unbound. An internal personal-export
helper has client execution revoked; the public wrapper adds templates/markers.

## Validation

Run [the disposable local checks](testing.md). pgTAP covers invariants, RLS,
direct-mutation attempts, deletion, collaboration and cursor boundaries.
Separate real Auth/PostgREST tests exercise concurrency and trusted Admin
deletion. A non-empty baseline upgrade compares rows and balances before/after
all forward migrations. Hosted migration execution and restore rehearsal remain
release gates.
