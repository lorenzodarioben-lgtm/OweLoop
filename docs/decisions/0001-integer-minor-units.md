# 0001: Store monetary amounts in integer minor units

- Status: Accepted
- Date: 2026-07-27

## Context

Shared-expense balances must reproduce exactly. Binary floating-point types can introduce rounding differences that are unacceptable for financial records.

## Decision

Store every persisted amount as a `bigint` count of the group's currency minor units. For example, USD 10.25 is stored as `1025`.

## Alternatives considered

- Floating-point columns were rejected because they cannot represent many decimal values exactly.
- PostgreSQL `numeric` was not selected for Version 0.1 because the product supports one currency per group and integer minor units make equality and balancing checks straightforward.

## Consequences

Expense, payer, split, and settlement values are exact integer arithmetic. Future currencies with non-standard minor-unit rules need explicit product support, and user interfaces must convert display values safely.

## Follow-up actions

Document display conversion rules before adding financial calculation services or user-facing amount entry.
