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

Feature code will own its models, repositories, state, screens, and tests. Shared concerns remain in `core` only when they genuinely serve more than one feature.

## Backend direction

Supabase configuration is read from `mobile/.env`, which is never committed. The client uses only the public anon key; privileged database access remains in Supabase server-side policy, functions, or trusted tooling. Future schema changes will be captured as ordered SQL migrations under `supabase/migrations/` and protected with Row Level Security.

The future data model will centre on users, groups, memberships (registered or guest), expenses, splits, payer contributions, settlements, and append-only audit events. Balance calculations will be reproducible from these records rather than being an unexplained mutable total.
