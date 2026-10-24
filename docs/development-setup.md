# Development setup

## Prerequisites

Install the current stable Flutter SDK, Node.js 20 or newer, and Docker Desktop. Start Docker Desktop's Linux engine before running local Supabase commands. Verify Flutter from a terminal:

```sh
flutter --version
flutter doctor
```

`flutter doctor` identifies missing platform tooling. Resolve the checks relevant to the platform you are developing for before attempting a native build.

## Windows

Install Flutter, Android Studio, and the Android SDK. Use Android Studio's SDK Manager to install a supported Android SDK platform, build tools, command-line tools, and an emulator image. Start an Android emulator or connect a physical device with developer options and USB debugging enabled.

Then run `flutter doctor` and accept Android SDK licences if requested:

```powershell
flutter doctor --android-licenses
```

## macOS

Install Flutter and Android Studio for Android development. For iOS development, install Xcode from the App Store, open it once to accept its licence, and install the required command-line tools. An iOS simulator can be managed from Xcode, or a physical device can be used with the appropriate Apple developer configuration.

iOS builds require macOS and Xcode; they cannot be produced from Windows or Linux.

## Linux

Install Flutter, Android Studio, and the Android SDK. Create an Android virtual device in Android Studio or connect a physical Android device with developer options and USB debugging enabled. Run `flutter doctor` to identify any missing Linux desktop or Android prerequisites relevant to your setup.

## Project configuration

From the repository root, create your local environment file:

```sh
cp mobile/.env.example mobile/.env
```

In Windows PowerShell:

```powershell
Copy-Item mobile/.env.example mobile/.env
```

Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` to development-project values. The mobile app must never contain a Supabase service-role key. Keep `mobile/.env` local; it is ignored by Git.

## Local database

The root npm lockfile provides the Supabase CLI; do not install the CLI globally. With Docker Desktop running, run the local-only workflow from the repository root:

```sh
npm ci
npm run db:start
npm run check:db
npm run db:stop
```

`npm run db:reset` applies migrations, `npm run db:test` runs pgTAP, and `npm run db:lint` checks the database schema. Do not link this local workflow to a hosted or production Supabase project.

## Run the app and checks

From `mobile/`:

```sh
flutter pub get
flutter run
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

From the repository root, use `./scripts/check.sh` on macOS/Linux or `.\scripts\check.ps1` on Windows PowerShell to run dependency installation, formatting verification, static analysis, and tests.

## Common problems

- **Flutter is not found:** add the Flutter SDK `bin` directory to your `PATH`, then restart the terminal.
- **No Android SDK found:** install and configure the Android SDK in Android Studio, then rerun `flutter doctor`.
- **No device is detected:** start an emulator, connect a physical device, and run `flutter devices`.
- **Environment configuration screen appears:** ensure `mobile/.env` exists and both required values are non-empty.
- **iOS build cannot start:** iOS builds require macOS with Xcode installed and configured.
- **Supabase commands cannot connect:** start Docker Desktop and wait for its Linux engine to be ready, then rerun `npm run db:start`.

## Current validation limitation

This workstation has Android SDK 36 installed, but command-line tools are missing and licence status is unknown. The attempted native build also failed before compilation because Gradle could not establish a loopback connection. Android builds cannot be claimed as validated here. Do not treat Flutter analysis or widget tests as native-build evidence; validate a native Android build after configuring the SDK. Release builds also require the local signing setup documented in [Android private beta preparation](android-private-beta.md).

## Functional sprint setup

Use the CI-pinned Flutter 3.44.2 / Dart 3.12.2 and Node 22 for reproducible checks.
On Windows, `.\scripts\check-local.ps1` creates/tests/stops its own temporary
Supabase project, avoiding the regular project's reserved port block. It does
not leave a development backend running. See [testing](testing.md) for flags,
real-service integration and native test commands. Start a disposable development
stack separately before running Flutter. Android emulators access the host via
`10.0.2.2`; never copy a service-role key into `mobile/.env`.

The same source successfully built an Android debug APK on Ubuntu/JDK17 in
[GitHub CI](https://github.com/lorenzodarioben-lgtm/OweLoop/actions/runs/40094829981).
The limitation above describes this workstation; device runtime remains untested.
