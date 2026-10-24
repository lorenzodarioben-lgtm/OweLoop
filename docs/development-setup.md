# Development setup

Begin with [START_HERE.md](../START_HERE.md) for the complete fresh-checkout path.
Use Flutter 3.44.2/Dart 3.12.2 (CI pinned), Node 22/npm, Git and Docker Desktop's
local Linux engine. PowerShell 5.1+ works on Windows; PowerShell 7 is optional on
macOS/Linux for the isolated test helper. No global Supabase install is needed.
The root lockfile pins CLI 2.109.1; `npm ci` installs it, including its platform package.

## App backend versus test backend

From the repository root:

```powershell
npm.cmd ci
npm.cmd run dev:check
npm.cmd run dev:start -- --configure-mobile
npm.cmd run dev:status
# After app development:
npm.cmd run dev:stop
```

These Node scripts also run on macOS/Linux with `npm`. Diagnostics check PATH,
Node version, installed local CLI and local Docker/Linux readiness; they do not
install tools or change configuration. `dev:start` explicitly creates ignored
`.local-dev/supabase/` with copied migrations/tests and a generated per-checkout
project ID. API 61421/DB 61422 leave the normal project's API 55421/DB 55422 untouched.
A stopped app project retains its local data. Never enter real user information
in it. Only SQL files are copied; no hosted link/configuration or credentials.

First start applies migrations. On repeat, `start` copies current SQL; apply new
forward migrations deliberately with:

```powershell
npx.cmd supabase migration up --local --workdir .local-dev
```

`--configure-mobile` writes only a new `mobile/.env` (public URL/anon key), never
overwrites an existing file or prints keys. If it refuses an existing `.env`, the
backend is still running; keep your configuration or move that file aside
manually before opting into a new local configuration. Plain `npm run dev:start`
never changes mobile configuration. Repeating identical setup is safe.

Android emulators use `10.0.2.2:61421`. For iOS simulators start with
`--configure-mobile --client-host=127.0.0.1`. Choose a different free block on the
**first** start with `--port-base=62420` if needed. Repeating a different port or
changed generated config is refused; use a separate checkout for incompatible
settings. Do not delete a working backend's files to bypass that guard. The
standard Supabase CLI remains available for deliberate local maintenance.

`check-local.ps1` instead creates, resets, tests and discards a unique temporary
project on API 60421/DB 60422. It does not leave the app backend running. Run only
one full backend check at a time; choose another block with `-PortBase 63420` if
needed. Do not run `npm run check:db` against app data you want to retain: that
legacy command resets the normal local project.

## Platform tools and app launch

From `mobile/` run `flutter pub get`, `flutter doctor -v`, `flutter devices`, then
`flutter run`. Missing/blank env values produce a configuration screen. Local
signup needs no SMTP/confirmation. The hosted deletion Edge gateway is not
configured by app setup; test its handler/local Admin path at test level 3 and
its actual deployment separately at level 5.

Android requires Android Studio, SDK 36/build tools, command-line tools, accepted
licences (`flutter doctor --android-licenses`), JDK 17 as in CI, and a running AVD
or USB-debugging device. API 35 emulator runtime is verified in CI. iOS requires
macOS/Xcode, simulator/device setup and signing where applicable. iOS cannot be
built on Windows/Linux. Physical devices need a reachable development endpoint;
Android's `10.0.2.2` address does not work on a phone. No firewall changes are made
by setup scripts. Use the reviewed [auth callback configuration](auth-redirects.md)
when testing real email links.

## Diagnose failures

- **Tool missing:** install it yourself and add its executable directory to PATH;
  restart the terminal, then rerun `npm run dev:check` / `flutter doctor -v`.
- **PowerShell blocks npm.ps1:** use `npm.cmd` / `npx.cmd` on Windows; no policy
  change is required. If script execution itself is restricted, use a process-only
  approved policy invocation or have your administrator review the signed/source
  script. Do not disable system protections.
- **Docker unavailable/remote/Windows containers:** start its local Linux engine;
  remote Docker is deliberately refused. Inspect `docker context show`.
- **Port conflict:** select a free block on first start; Windows can reserve 55422.
- **No device:** `flutter devices` must list the intended target. Starting a
  backend does not create an emulator, accept licences or install Xcode.
- **Gradle loopback error:** the outgoing Windows host failed before compilation
  even with JDK 21/IPv4. This is a host failure; preserve the exact error and use
  CI/JDK 17 or a correctly configured development host. Never disable a firewall
  or claim local success from CI. See [Android preparation](android-private-beta.md).
- **Flutter SDK lock/cache failure:** avoid concurrent Flutter commands. Check
  SDK write access and `FLUTTER_ROOT`/PATH consistency; do not delete user SDKs.

[Testing levels](testing.md) distinguish quick, full, backend, native and release
checks. [HANDOFF](../HANDOFF.md) records the actual cold-clone rehearsal and
platform limits; [Sprint II](SPRINT_II_REPORT.md) preserves earlier exact-head CI
and Android emulator evidence. Claude Code is optional tooling: follow its
[official quickstart](https://code.claude.com/docs/en/quickstart), then run `claude`
from the repository root; no agent account or credential is shipped here.
