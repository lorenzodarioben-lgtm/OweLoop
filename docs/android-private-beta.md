# Android private beta preparation

## Identity and versioning

The Android application ID remains `com.oweloop.oweloop`. It is a suitable, product-owned reverse-domain identifier and should not change after the first Play Console registration. The private-beta Flutter version is `0.1.0+1`; increase the build number for every tester build uploaded to a distribution channel.

The Android launcher label is `OweLoop`, and the main manifest owns the minimal `INTERNET` permission needed by hosted Supabase builds. Debug and profile manifests may retain their development declarations, but release connectivity must never depend on them.

## Release signing

Release builds deliberately fail when a local signing configuration is absent. They must never fall back to the debug signing key.

1. Generate or obtain a team-controlled Android upload keystore outside this repository.
2. Make a local copy of [`mobile/android/key.properties.example`](../mobile/android/key.properties.example) at `mobile/android/key.properties`.
3. Replace every placeholder with the local keystore path, alias, and passwords. The path is relative to `mobile/android/`.
4. Keep the keystore, `key.properties`, and passwords in the team password manager or approved secure storage. They are ignored by Git.
5. On a controlled machine, run `flutter build appbundle --release` from `mobile/`. The build should fail clearly if signing is incomplete or the keystore is unavailable.

Do not use a debug-signed APK or AAB for a private beta intended for external testers.

## Branding hand-off

The current launcher assets are the stock Flutter icon and the launch background is intentionally plain. Before external distribution, supply reviewed OweLoop launcher icon assets for Android density buckets/adaptive icon support and a branded splash asset if the product team wants one. This sprint does not invent permanent marketing artwork without approved source assets.

## Device validation gate

Android SDK 36 is now present, but command-line tools/licence validation are incomplete. A debug-build attempt failed while Gradle established its loopback connection, before native compilation. Repair the toolchain and connect an emulator/device, then run:

```sh
cd mobile
flutter doctor -v
flutter build apk --debug
```

Then perform the private-beta smoke checks on a physical device: first launch, sign-in, group invitation, expense, settlement, app restart, and offline/error recovery. Only test release signing after the controlled local signing material has been configured.

The independent Android debug build passed on Ubuntu/JDK17 in
[GitHub Mobile CI](https://github.com/lorenzodarioben-lgtm/OweLoop/actions/runs/40094829981)
at engineering checkpoint `283cb79`. This resolves compilation evidence while
leaving this host's loopback/SDK repair and all physical-runtime checks open.
