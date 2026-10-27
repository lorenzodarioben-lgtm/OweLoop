# OweLoop agent instructions

## Project purpose

OweLoop is a shared-expense mobile application for Android and iOS. It is intended to make shared expenses reliable and understandable through unlimited manual expense entry, guest participation, transparent balances, strong expense audit history, and dependable expense calculations.

## Current project stage

The repository implements the shared-expense core and two functional sprints.
Android emulator recovery is verified; physical-device/iOS and hosted release
gates remain open. Read [START_HERE.md](START_HERE.md), [HANDOFF.md](HANDOFF.md),
and relevant architecture/ADRs before changing code. Historical reports are
checkpoint evidence; the handoff records later onboarding validation.

## Technology stack

- Flutter and Dart for the mobile application.
- Riverpod for state management and dependency injection.
- GoRouter for navigation.
- Supabase and PostgreSQL for authentication and backend data.
- GitHub Actions for continuous integration.

## Repository structure

- `mobile/` contains the Flutter Android and iOS application.
- `supabase/` contains ordered migrations, pgTAP and the trusted deletion function.
- `docs/` contains product, architecture, delivery, and collaboration documentation.
- `.github/` contains GitHub Actions and issue or pull request templates.

## Required workflow

Before changing code, every agent must:

1. Read this file and relevant documentation.
2. Run `git status` and inspect recent commits.
3. Understand the existing implementation and assigned task.
4. Avoid overwriting unrelated work.
5. Keep changes limited to the assigned task.

After changing code, every agent must:

1. Format changed Dart code.
2. Run static analysis and relevant tests.
3. Review the diff and check for secrets.
4. Report every changed file.
5. Leave a clean working tree after committing when a commit was requested.

### Standard commands

From the repository root:

```sh
./scripts/check.sh
```

```powershell
.\scripts\check.ps1
```

From `mobile/`:

```sh
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter run
```

For the local database from the repository root (Docker Desktop must be running):

```sh
npm ci
npm run db:start
npm run db:reset
npm run db:test
npm run db:lint
npm run db:stop
```

The Supabase CLI is project-local. Do not install it globally, link routine checks to a hosted project, or use production credentials for local validation.

For an isolated app backend use `npm ci`, `npm run dev:check`, then explicitly
`npm run dev:start -- --configure-mobile` on a fresh checkout. Stop with
`npm run dev:stop`. For full isolated backend/security/upgrade/API checks use
`.\scripts\check-local.ps1 -SkipInstall -DartIntegration` on Windows (PowerShell 7
also supports this helper on macOS/Linux). See [testing](docs/testing.md).

## Architecture boundaries

- UI code must not contain financial calculation logic.
- Business logic should remain testable independently of Flutter widgets.
- Supabase service-role keys must never be included in the mobile application.
- Secrets must not be committed; use the ignored `mobile/.env` file for local development values.
- Database changes must use ordered migrations under `supabase/migrations/`.
- Row-Level Security must be enabled and reviewed for user-owned data.
- Product scope must not be expanded without updating the relevant documentation.
- Do not introduce major dependencies without a documented justification.
- Preserve integer minor units, checked ranges and deterministic allocation.
- Preserve transaction locks, current caller authorization, RLS and guarded RPCs;
  never add direct mutation bypasses or edit historical applied migrations.
- Posted financial rows/audit history and group-member UUIDs are durable;
  void/duplicate corrects an expense. Claim/removal/deletion never replaces IDs.
- Persist financial requests before send, with account-scoped secure storage.
  Android secure-store completion includes the native disk fence; a failed or
  timed-out fence cannot authorize a network send, including an explicit retry.
  Unknown outcome or missing lookup is not failure. Retry only the original ID
  and payload; a rejected retry cannot erase previous uncertainty.
- Drafts/templates are separate from financial operations and never auto-post.
- Recurrence uses server-calendar due proposals with pinned template snapshots.
  Preserve unique occurrence dates, atomic expense completion and original
  pending request identities; schedules never post without explicit review.
- Account deletion requires zero membership balances and no active ownership;
  trusted server validation/de-identification preserves shared history.
- Receipts use private authenticated downloads and the trusted upload gateway.
  Preserve digest-bound intents, service-only completion/cleanup and restrictive
  Storage policies; uncertain completion never authorizes deleting a ready file.
- Keep export files/private read state account-scoped; cleanup must preserve
  pending/unknown operations. Never log credentials or raw recovery payloads.
- Preserve Auth/provider generation guards across account changes and sign-out.
- Update HANDOFF.md after significant work; keep setup, ADRs and scope accurate.
- Keep visual design independent of domain logic; consult the neutral design
  handoff. Report unavailable/skipped tests honestly. Deployment, physical
  devices/iOS, callbacks/sharing, signing and operational gates need real evidence.

## Collaboration rules

- Complete one task per branch where practical.
- New contributions branch from `codex/functional-completion` while PR #8 remains
  unmerged; target that branch in the PR, then retarget after baseline merge.
  Follow [CONTRIBUTING.md](CONTRIBUTING.md) for collaborator and fork commands.
- Avoid editing the same files simultaneously with another contributor.
- Use GitHub issues or clearly documented tasks to define work.
- Pull requests must explain their scope, testing, and risks.
- Do not delete or rewrite another contributor's work merely to simplify an implementation.
- Resolve merge conflicts carefully; do not automatically choose one side.
- Respect existing architecture decisions unless the task explicitly changes them.

## Git safety and attribution

Use the human operator's existing Git identity. Each human contributor must use their own identity and must not claim authorship for work they did not perform.

Agents must not:

- Force-push, rewrite shared history, or amend another contributor's commits.
- Delete branches belonging to other contributors.
- Commit generated build output, `.env` files, Android signing keys, Apple certificates, or provisioning profiles.
- Create fake, inflated, or artificial commits.
- Add Codex, OpenAI, an AI assistant, model, or bot as an author or contributor.
- Add AI co-author trailers.

## Commit quality

- Each commit represents one coherent change.
- Use conventional commit-style messages.
- Avoid unrelated formatting changes and artificial commit splitting.
- Use the human operator's existing Git identity.
