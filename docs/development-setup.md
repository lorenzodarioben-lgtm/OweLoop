# Development setup

## Prerequisites

Install the current stable Flutter SDK and verify it from a terminal:

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

## Current validation limitation

The initial application foundation was not validated with an Android build because the original development machine did not have an Android SDK configured. Do not treat that as evidence of an Android build result; validate a native Android build after configuring the SDK.
