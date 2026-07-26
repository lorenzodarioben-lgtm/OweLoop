#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root/mobile"

echo "Installing Flutter dependencies..."
flutter pub get

echo "Verifying Dart formatting..."
dart format --set-exit-if-changed .

echo "Running Flutter static analysis..."
flutter analyze

echo "Running Flutter tests..."
flutter test
