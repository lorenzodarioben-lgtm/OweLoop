# Contributing to OweLoop

Thanks for helping build OweLoop. The repository is intentionally at an early stage, so please read [AGENTS.md](AGENTS.md), the [architecture](docs/architecture.md), and the [roadmap](docs/roadmap.md) before starting work.

## Required software

- Git.
- The current stable Flutter SDK.
- An Android SDK and emulator or physical Android device for Android development.
- Xcode for iOS development on macOS only.

You may use any editor or IDE that works well with Flutter; none is required by this project.

## Get started

Clone the repository and enter it:

```sh
git clone https://github.com/lorenzodarioben-lgtm/OweLoop.git
cd OweLoop
```

Create local mobile configuration from the example. On macOS or Linux:

```sh
cp mobile/.env.example mobile/.env
```

On Windows PowerShell:

```powershell
Copy-Item mobile/.env.example mobile/.env
```

Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` to development-project values. Never put a Supabase service-role key, password, token, or other secret in source control.

Install dependencies and run the application:

```sh
cd mobile
flutter pub get
flutter run
```

Run checks from `mobile/`:

```sh
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Or run all checks from the repository root with `./scripts/check.sh` on macOS/Linux or `.\scripts\check.ps1` in Windows PowerShell.

## Branches and commits

Use one focused task per branch where practical. Suggested branch names include:

- `feature/group-creation`
- `fix/balance-rounding`
- `docs/database-design`
- `test/expense-calculator`

Use conventional commit-style messages, for example:

```text
feat: add group creation form
fix: preserve cents in balance calculation
docs: document database migration workflow
test: cover equal expense split
```

Each human contributor must configure and use their own Git name and email. Do not use another person's identity, and do not add AI tools as authors or co-authors.

## Pull requests

Before opening a pull request, keep the scope tied to a GitHub issue or documented task, run the relevant checks, review your diff, and update documentation when behaviour or architecture changes. Describe the scope, testing, risks, and any follow-up work in the pull request template.

Avoid unrelated formatting changes. Do not delete or overwrite another contributor's work to simplify your own changes. When people or agents are working in parallel, coordinate file ownership early and resolve merge conflicts deliberately.

## Secret handling

`mobile/.env` is local-only and ignored by Git; `mobile/.env.example` is the tracked template. Never commit `.env` files, service-role keys, Android signing keys, Apple certificates, provisioning profiles, passwords, access tokens, or generated build output.
