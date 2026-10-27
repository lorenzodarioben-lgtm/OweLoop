@AGENTS.md

# Claude Code project entry

OweLoop is a Flutter/Dart shared-expense ledger using Riverpod, GoRouter and
Supabase/PostgreSQL. It records expenses and external settlements, never payments.
The imported AGENTS.md is the shared authority; keep rules there consistent.

Read [START_HERE.md](START_HERE.md) for setup, [HANDOFF.md](HANDOFF.md) for continuity,
and the relevant [roadmap task](docs/roadmap.md) before editing. Features live in
`mobile/lib/features/`, recovery in `mobile/lib/core/operations/`, SQL in
`supabase/migrations/`, tests in `mobile/test/` and `supabase/tests/database/`.

From root: `npm ci`, `npm run dev:check`, then explicitly
`npm run dev:start -- --configure-mobile` for a fresh local app environment.
Windows: `.\scripts\check.ps1` and
`.\scripts\check-local.ps1 -SkipInstall -DartIntegration`.
macOS/Linux: `./scripts/check.sh`; optional PowerShell 7 runs the isolated backend
helper with `pwsh -File scripts/check-local.ps1 -SkipInstall -DartIntegration`.
See [testing levels](docs/testing.md) for prerequisites, commands and unavailable
platform checks. Stop the app backend with `npm run dev:stop`.

Future changes use an independent branch from `codex/functional-completion`
while PR #8 is unmerged; never merge or deploy without explicit owner authorization.
Update HANDOFF.md after significant work. Preserve integer money, deterministic
allocations, immutable durable member history, guarded authorization and same-ID
unknown-outcome recovery. No service role in Flutter. No historical migration edits.
Plain Material UI is intentional; design must remain independent of domain logic.
Physical devices/iOS, hosted lifecycle/SMTP, signing and operational release gates
remain open. Report actual tests and skips; do not infer a pass from source alone.
