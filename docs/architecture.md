# Architecture

## Technology stack

- Flutter and Dart provide one Android and iOS client.
- Supabase provides authentication and a PostgreSQL backend.
- Riverpod will manage application state and dependency injection.
- GoRouter owns declarative navigation.
- GitHub Actions verifies formatting, analysis, and tests on every push and pull request.

## Application structure

The Flutter application uses a feature-first layout:

```text
mobile/lib/
├── app/                 # app shell and navigation
├── core/
│   ├── config/          # environment configuration
│   ├── errors/          # startup error presentation
│   ├── theme/           # shared Material theme
│   └── utils/           # future shared utilities
├── features/
│   ├── authentication/
│   ├── groups/
│   ├── expenses/
│   └── settlements/
└── main.dart
```

Feature code owns its models, repositories, state, screens, and tests. Shared concerns remain in `core` only when they genuinely serve more than one feature.

The `authentication` feature has repository interfaces alongside Supabase implementations, an `AuthenticationController` for session and profile state, pure validation and safe error mapping, and presentation widgets. Widgets submit user intent to the controller; they do not call Supabase or contain database rules.

At startup the controller restores the existing Supabase session, loads the private profile, and remains in a loading state until that work completes. It listens for sign-in, sign-out, token-refresh, and user-update events, clearing profile state after sign-out. GoRouter observes this state and applies testable redirect rules: signed-out users go to `/sign-in`, authenticated users with incomplete onboarding go to `/profile-setup`, and users with completed onboarding go to `/home`. The `/loading` route is intentionally separate so a loading state is never treated as signed out.

The `groups` feature follows the same repository/controller/presentation split. Its group-list controller reloads when an authenticated session becomes available and clears its in-memory list when that session ends. GoRouter protects `/groups/new` and `/groups/:groupId` with the same authentication and onboarding redirects as `/home`; group-detail data is still loaded through Supabase RLS, so a manually changed ID is treated as unavailable rather than exposing private group data.

The `expenses` feature uses the same boundary. It owns integer-only money parsing, deterministic equal-split previewing, repository access, loading/error state, and its own presentation screens. The group detail screen hosts expense history, while `/groups/:groupId/expenses/new` creates an expense and `/groups/:groupId/expenses/:expenseId` shows its details. The detail controller verifies that the loaded expense belongs to the group path segment, so manually mismatched routes are unavailable. Expense history and creation state clear when authentication ends.

The `balances` feature is read-only. Its repository calls the narrow `get_group_balances` RPC with only a group ID, then maps database `bigint` minor units into the existing exact-money value object. The controller owns ordering, loading, retry, and sign-out cleanup; presentation code only states the returned balance. The group detail screen hosts the balance summary and participant ledger, refreshes it with the rest of the group, and refreshes it after a successful expense post. No client widget calculates financial balances.

The `settlements` feature records an external payment through the guarded `record_settlement` RPC, renders chronological history, and voids a record without deletion. The `expenses` feature now sends one validated generic payload to `create_expense`, which represents one or multiple payers and final exact allocations for equal, exact, percentage, or share splits. A posted expense remains immutable; correction is a void followed by a prefilled new-expense form. The `activity` feature reads only the safe `get_expense_activity` projection rather than raw event snapshots.

The `groups` settings route exposes only controls allowed by the current role. Guarded database functions rename and archive groups or remove members; existing guarded role and ownership operations remain owner-only. The `repayments` feature is pure domain logic layered over the canonical balance read. It uses integer amounts, validates a zero group total, orders ties deterministically, and hands a suggested active-member transfer to the settlement form as a draft. It never writes a financial record or transfers money by itself.

## Backend direction

Supabase configuration is read from `mobile/.env`, which is never committed. The client uses only the public anon key; privileged database access remains in Supabase server-side policy, functions, or trusted tooling. Schema changes are captured as ordered SQL migrations under `supabase/migrations/` and protected with Row Level Security.

The ordered migrations establish profiles, groups, durable memberships for registered users and guests, expenses, payer contributions, splits, settlements, and append-only expense events. Later migrations add explicit onboarding, guarded guest creation, equal entry, transparent balances, settlement recording, generic flexible expense creation, safe expense activity, and group administration. Public database functions use fixed search paths and caller-derived authority; all client-accessible tables use RLS. Financial records use integer minor units, and only exact posted records contribute to balances. See the [database design](database-design.md), [security model](security-model.md), and related [ADRs](decisions/README.md).
