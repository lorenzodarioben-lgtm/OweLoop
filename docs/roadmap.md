# Roadmap

## Foundation - complete

- Flutter Android and iOS project in `mobile/`.
- Environment-based Supabase startup configuration.
- Riverpod root scope and GoRouter application shell.
- Initial test coverage and continuous integration.
- Documentation and migration directory.
- Secure Supabase/PostgreSQL core schema, Row-Level Security, database tests, and decision records.

## Version 0.1 - shared-expense core complete

1. Authentication and account lifecycle - complete for email/password access and required profile onboarding.
2. Groups with registered and guest members - complete for creation, viewing, guest addition, safe removal, owner-only role and ownership changes, and archive. Invitations and guest claiming remain later work.
3. Flexible expenses - complete for one or multiple payers; equal, exact, percentage, and share splits; exact previews; posted history; detail; and correction by void-and-duplicate.
4. Transparent per-group balances - complete for exact, settlement-aware, read-only balances and deterministic repayment suggestions.
5. Settlement recording and history - complete for recording externally completed payments and voiding history.
6. Basic expense audit history - complete for safe creation, allocation, finalization, and void activity.

## Before a public beta

- Build and test on configured Android and iOS toolchains and physical devices.
- Configure a non-local Supabase project, email delivery, and environment values without committing secrets.
- Design invitations, guest claiming, and account-deletion support flows.
- Add accessibility, localization, performance, migration-upgrade, and end-to-end test coverage.
- Establish privacy, support, monitoring, backup, incident-response, release, store-listing, and signing processes.

## Later versions

Receipt scanning, AI assistance, subscriptions, bank integrations, payment processing, advanced analytics, multiple currencies, and full offline synchronisation will be evaluated only after the Version 0.1 shared-expense workflow is stable.
