# Contributing to OweLoop

Start with [START_HERE.md](START_HERE.md), [AGENTS.md](AGENTS.md) and
[HANDOFF.md](HANDOFF.md). Use Flutter 3.44.2/Dart 3.12.2, Node 22/npm and local
Docker Linux. [Setup](docs/development-setup.md) and [testing levels](docs/testing.md)
contain the executable commands. Each human uses their own existing Git identity;
check it with `git var GIT_AUTHOR_IDENT`. Never copy another contributor's identity.

## Choose the correct base

PR #8 is the unmerged functional baseline. Until it merges, **branch from and open
PRs against `codex/functional-completion`**. Do not commit directly to `master` or
the handover branch. After PR #8 merges, fetch and start new work from `origin/master`;
retarget existing stacked PRs deliberately and resolve conflicts without discarding
work. No force pushes, shared-history rewrites, AI authors or co-author trailers.

With collaborator write access, from a clean checkout:

```powershell
git status --short
git fetch origin
git switch -c test/native-draft-restart origin/codex/functional-completion
```

Without write access, use GitHub's **Fork** action first. In the checkout created
by START_HERE (whose `origin` points to the source repository), preserve the source
as `upstream` and add your own fork. Enter your actual login when prompted:

```powershell
$githubLogin = Read-Host 'Your GitHub login'
git remote rename origin upstream
git remote add origin "https://github.com/$githubLogin/OweLoop.git"
git fetch upstream
git switch -c test/native-draft-restart upstream/codex/functional-completion
```

On macOS/Linux set `githubLogin` with `read -r githubLogin` and use the same Git
commands with shell variable expansion. A fresh clone of your fork also works;
add the source as `upstream`, fetch it, then branch from its handover ref.
No collaborator permission or access token is created by these instructions.

## One focused change

The recommended first task is [P1 draft restart coverage](docs/roadmap.md).
Change only the files needed for the selected task. Existing issues or a concrete
roadmap item define scope. Keep domain logic outside widgets; retain exact money,
deterministic allocations, immutable audit history and guarded authorization.
Unknown outcomes must retain the original operation ID/payload. No service role in
Flutter, direct DML escape hatch or automatic financial posting.

For SQL, add the next ordered UTC `YYYYMMDDHHMMSS_description.sql` under
`supabase/migrations/`; never modify an applied migration. Update RLS/grants and
adversarial pgTAP when a data surface changes. Use the [ADR process](docs/decisions/README.md)
for significant decisions. Update HANDOFF.md after significant work and keep
product/setup/design contracts current. Styling remains independent of domain code.

## Verify, commit and submit

After editing, run the relevant [test levels](docs/testing.md). For Flutter changes:

```powershell
.\scripts\check.ps1
```

For SQL/backend changes (Docker running):

```powershell
.\scripts\check-local.ps1 -SkipInstall -DartIntegration
```

Then review/stage only actual changed paths (the example file below is for the
recommended first task):

```powershell
git diff --check
git diff
git add mobile/integration_test/recovery_probe_app.dart scripts/test-android-recovery.mjs
git diff --cached
git commit -m 'test: verify unsent drafts survive native restart'
git push -u origin test/native-draft-restart
```

The commit example is a name for your completed work, not an instruction to make
an empty or artificial commit. Use conventional messages and cohesive changes.
Open a PR on GitHub from your pushed branch/fork into the source repository's
`codex/functional-completion`. With authenticated optional GitHub CLI:

```powershell
gh pr create --repo lorenzodarioben-lgtm/OweLoop --base codex/functional-completion --web
```

For fork PRs select your fork and branch in the browser comparison. Use the
[PR template](.github/pull_request_template.md); explain problem/result, scope,
commands and real outcomes, risks and follow-up. Include skipped/unavailable
checks with their reason; written tests are not execution evidence. Attach
screenshots only when useful. Inspect Mobile CI (format/analyze/tests/debug APK),
Database CI (pgTAP/lint/handler/upgrade/HTTP) and the separate native workflow when
its paths change. Repository branch-protection settings may impose additional
checks; do not assume permissions or a particular protection configuration.

Keep `.env`, `.local-dev`, generated output, signing keys, Apple certificates and
credentials untracked. Never link routine checks to hosted data. Coordinate file
ownership before parallel work, preserve others' changes, and resolve conflicts
explicitly. PR review and owner-approved beta/release work are separate; do not
merge or deploy as part of an ordinary contribution.
