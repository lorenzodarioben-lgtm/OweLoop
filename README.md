# OweLoop

OweLoop is a mobile app for recording shared expenses clearly, without limits or opaque balances. It is being built for students, roommates, couples, and group travellers who need an understandable record of who paid, who owes, and why.

The initial implementation lives in [`mobile/`](mobile/). It uses Flutter, Supabase, Riverpod, and GoRouter.

## Current project status

The repository currently contains the application and collaboration foundations only. Authentication, groups, expenses, settlements, database tables, and migrations have not been implemented yet. The planned Version 0.1 scope is documented in the [product requirements](docs/product-requirements.md) and [roadmap](docs/roadmap.md).

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

## Repository layout

- `mobile/` — Flutter Android and iOS application.
- `supabase/migrations/` — future version-controlled database migrations.
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

## Contribution workflow

Read [AGENTS.md](AGENTS.md) and [CONTRIBUTING.md](CONTRIBUTING.md) before changing code. Keep work focused, use one task per branch where practical, run the checks, review the diff, and describe scope, testing, and risks in pull requests.

For a reusable task handoff, use the [agent handoff template](docs/agent-handoff-template.md). Significant architecture decisions should use the [ADR process](docs/decisions/README.md).
