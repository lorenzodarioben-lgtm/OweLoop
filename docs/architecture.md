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

## Backend direction

Supabase configuration is read from `mobile/.env`, which is never committed. The client uses only the public anon key; privileged database access remains in Supabase server-side policy, functions, or trusted tooling. Schema changes are captured as ordered SQL migrations under `supabase/migrations/` and protected with Row Level Security.

The first database migration establishes profiles, groups, durable memberships for registered users and guests, expenses, payer contributions, splits, settlements, and append-only expense events. The profile-onboarding migration adds an explicit completion timestamp and a guarded profile-completion database function. The group-management migration normalizes direct group creation before the existing owner-membership trigger runs, and exposes a narrow guest-only membership function. All client-accessible tables use RLS. Financial records use integer minor units, and expenses follow a draft-and-finalise workflow so only exact, posted records contribute to future balances. See the [database design](database-design.md), [security model](security-model.md), and related [ADRs](decisions/README.md).
