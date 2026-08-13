# 0008: Keep repayment suggestions read-only

- Status: Accepted
- Date: 2026-08-04

## Context

Users benefit from a smaller set of repayments, but OweLoop does not process, verify, or initiate money movement. Recommendations must not become a second balance system.

## Decision

Calculate deterministic suggestions in pure client domain logic from the canonical reconciled group-balance result. Use only integer minor units; reject non-zero or mixed-currency totals; retain guests and historical members; and send an active-member suggestion only as a prefilled settlement-record draft.

## Alternatives considered

- Storing suggested repayments was rejected because they become stale after any expense or settlement.
- A separate database balance model was rejected because it duplicates the canonical balance RPC.
- Automatically creating or processing settlements was rejected because it asserts that money moved without evidence.

## Consequences

Suggestions are transparent, repeatable, and cannot change balances unless a user explicitly records an external payment. Suggestions involving removed participants stay visible for historical understanding but cannot be recorded through the active-member settlement form.

## Follow-up actions

Revisit server-side calculation only if group size or client-performance evidence requires it, retaining the same canonical balance and exact-money rules.
