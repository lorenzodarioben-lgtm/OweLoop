# 0007: Correct posted expenses by voiding and duplicating

- Status: Accepted
- Date: 2026-08-02

## Context

Editing a posted expense would rewrite the record that members used to understand previous balances and make audit history harder to trust.

## Decision

Keep posted expense allocations immutable. A creator or group administrator can void an expense once, which preserves it and excludes it from balances. The client can prefill its values into a new expense form for review and posting as a new record.

## Alternatives considered

- In-place editing with audit snapshots was rejected because the original calculation would no longer be directly visible.
- Hard deletion was rejected because it loses financial history.
- Automatic replacement posting was rejected because the user must review a correction before it affects balances.

## Consequences

Balances remain derived from clear posted records, and corrections have an explicit immutable trail. History may contain both the voided original and its independent replacement, so product language must explain the status clearly.

## Follow-up actions

Consider optional, non-authoritative links between an original and its replacement only if users need stronger correction discoverability.
