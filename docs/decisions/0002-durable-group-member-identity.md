# 0002: Represent registered users and guests with durable group members

- Status: Accepted
- Date: 2026-07-27

## Context

Expense history must remain understandable when participants are guests, later register, leave a group, or delete an account. Referencing only `auth.users` would make guest participation and historical preservation unsafe.

## Decision

Use `group_members` as the durable participant identity. It has its own UUID, a display-name snapshot, a nullable `user_id`, role, and removal timestamp. Financial records reference the group-member UUID, not the auth-user UUID directly.

## Alternatives considered

- Requiring every participant to create an account was rejected because it excludes temporary guests.
- Storing guest names directly on every payer or split row was rejected because identity changes and history would be difficult to reconcile.

## Consequences

Guests cannot access the database directly. A future guest-claim workflow must link an authenticated user to the existing group-member row rather than create a replacement. Account deletion preserves financial history by setting the user link to null.

## Follow-up actions

Design controlled guest-claim, invitation, and account-deletion workflows before exposing them in the application.
