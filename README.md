# OweLoop

OweLoop is an idea for a mobile app for recording shared expenses clearly, without limits or opaque balances. It is being built for students, roommates, couples, and group travellers who need an understandable record of who paid, who owes, and why.

The initial implementation lives in [`mobile/`](mobile/). It uses Flutter, Supabase, Riverpod, and GoRouter.

## Current project status

The repository now contains the Version 0.1 shared-expense core plus private-beta readiness work: email-and-password access with verification resend and password recovery; groups with registered and guest members; exact expenses with one or multiple payers and equal, exact, percentage, or share-based splits; settlement recording and immutable history; transparent group balances; expense activity; correction by void-and-duplicate; group administration; repayment suggestions; in-app registered-user invitations; and explicit two-party guest account claims. Balances and suggestions derive from posted, non-voided expenses and non-voided settlements using integer minor units. OweLoop records payments that have already happened; it never moves money automatically.

## Local database development

The Supabase CLI is a project-local development dependency. Install Node.js 20 or newer and start Docker Desktop before running local database checks:

```sh
npm ci
npm run db:start
npm run check:db
npm run db:stop
```

`db:reset` applies the ordered migrations, `db:test` runs pgTAP tests, and `db:lint` checks the schema. These commands use the local Supabase stack only; do not link them to a hosted or production project.

## Getting started

1. Install the current stable Flutter SDK.
2. Copy `mobile/.env.example` to `mobile/.env`.
3. Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` with development-project values. Do not use a Supabase service-role key in the app.
4. Run the commands from `mobile/`:

   ```sh
   flutter pub get
   flutter run
   ```

`mobile/.env` is intentionally ignored by Git. Missing or blank values produce a clear development configuration screen.

For sign-up testing, configure email confirmation in the development Supabase project according to the desired behaviour. If confirmation is enabled, Supabase may return no session after sign-up; OweLoop then shows a verification-pending screen and does not grant access until a valid session is restored.

## Repository layout

- `mobile/` — Flutter Android and iOS application.
- `supabase/migrations/` — version-controlled database migrations.
- `docs/` — product, architecture, and delivery planning.
- `.github/workflows/` — continuous integration.

See the [product requirements](docs/product-requirements.md), [architecture](docs/architecture.md), and [roadmap](docs/roadmap.md).

## Private beta preparation

Hosted deployment is intentionally manual and remains unconfigured in this
repository. Before inviting testers, follow the [hosted environment and
migration runbook](docs/hosted-beta-environments.md), complete the
[two-account test plan](docs/private-beta-test-plan.md), and record the
[release checklist](docs/private-beta-release-checklist.md). Support, privacy,
and crash-reporting decisions are tracked in [private beta operations](docs/private-beta-operations.md).

## Development setup

Platform-specific setup, Android SDK requirements, and common troubleshooting steps are in the [development setup guide](docs/development-setup.md). Run `flutter doctor` after installing Flutter to identify missing platform tooling.

## Running checks

From the repository root, run all mobile checks with:

```sh
./scripts/check.sh
```

On Windows PowerShell:

```powershell
.\scripts\check.ps1
```

The scripts install Flutter dependencies, verify formatting, run static analysis, and execute tests. You can also run the same commands directly from `mobile/`.

Run the local database check separately from the repository root with `npm run check:db`; Docker Desktop must be running.

## Contribution workflow

MUST Read [AGENTS.md](AGENTS.md) and [CONTRIBUTING.md](CONTRIBUTING.md) before changing code. Keep work focused, use one task per branch where practical, run the checks, review the diff, and describe scope, testing, and risks in pull requests.

For a reusable task handoff, use the [agent handoff template](docs/agent-handoff-template.md). Significant architecture decisions should use the [ADR process](docs/decisions/README.md).

## Functional completion sprint

The current implementation adds checked largest-remainder splits, guarded
membership mutations, encrypted account-scoped financial retry/reconciliation,
normal nested back navigation, complete cursor-based financial history,
expense discovery, saved unsent drafts, CSV ledger exports, profile editing,
personal JSON export, safe group leaving, and a deployable password-confirmed
account-deletion component that preserves shared financial history. Sprint II
adds audited archive recovery, optional expense categories, settlement filters,
single-snapshot ledger exports, private CSV/JSON file sharing, reusable expense
templates, a private activity inbox and device-scoped currency/cleanup settings.
Templates require explicit review and posting; no scheduler moves money.

Start with [HANDOFF.md](HANDOFF.md), the
[functional completion report](docs/FUNCTIONAL_COMPLETION_REPORT.md), and
[reproducible testing](docs/testing.md). The
[design handoff](docs/DESIGN_HANDOFF.md) documents functional contracts without
prescribing a visual style. Hosted deletion deployment and physical-device
validation remain release gates; code and local tests are not deployment claims.

On Windows, `.\scripts\check-local.ps1` validates a uniquely named disposable
Supabase stack without resetting the developer's regular project.
