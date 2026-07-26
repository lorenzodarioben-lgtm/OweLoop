# 0003: Finalize expenses through a guarded database transaction

- Status: Accepted
- Date: 2026-07-27

## Context

Creating an expense requires a parent row plus payer and split rows. Immediate row-level total constraints would reject valid multi-step creation before all rows exist, while accepting posted expenses without exact totals would compromise balances.

## Decision

Create expenses as drafts. Authorised clients build payer and split rows while the expense is a draft, then call `public.finalize_expense(uuid)`. The function locks the draft and children, verifies both sums equal the expense total, and posts the expense in one transaction. Posted children are immutable.

## Alternatives considered

- Deferred constraint triggers were not selected because they complicate ordinary client transactions and error recovery.
- A client-only calculation was rejected because an untrusted client cannot enforce the financial invariant.
- Requiring one opaque JSON payload was rejected because normalized payer and split rows are needed for auditability and future calculation features.

## Consequences

Incomplete drafts may exist but are not financially final. All balance calculations must include only posted, non-voided expenses. The future mobile client needs a clear save-draft and finalize flow.

## Follow-up actions

Add service-level tests for concurrent edits and user-facing draft recovery when expense workflows are implemented.
