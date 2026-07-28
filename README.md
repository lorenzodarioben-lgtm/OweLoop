# OweLoop

OweLoop is an idea for a mobile app for recording shared expenses clearly, without limits or opaque balances. It is being built for students, roommates, couples, and group travellers who need an understandable record of who paid, who owes, and why.

The initial implementation lives in [`mobile/`](mobile/). It uses Flutter, Supabase, Riverpod, and GoRouter.

## Current project status

The repository contains the application and collaboration foundations, a secure Version 0.1 database foundation, and the first complete mobile feature: email-and-password authentication with profile onboarding. After authentication, each user chooses a display name before reaching the authenticated home screen. Groups, expenses, settlements, and other Version 0.1 workflows remain planned work; see the [product requirements](docs/product-requirements.md) and [roadmap](docs/roadmap.md).

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

Read [AGENTS.md](AGENTS.md) and [CONTRIBUTING.md](CONTRIBUTING.md) before changing code. Keep work focused, use one task per branch where practical, run the checks, review the diff, and describe scope, testing, and risks in pull requests.

For a reusable task handoff, use the [agent handoff template](docs/agent-handoff-template.md). Significant architecture decisions should use the [ADR process](docs/decisions/README.md).
