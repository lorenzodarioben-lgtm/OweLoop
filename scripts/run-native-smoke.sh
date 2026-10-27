#!/usr/bin/env bash
# Both independent runtime probes execute even when one fails. No hosted data.
set -u
cd mobile || exit 1
flutter test integration_test/private_beta_journey_test.dart -d emulator-5554 \
  --dart-define=OWELOOP_TEST_SUPABASE_URL=http://10.0.2.2:55421 \
  --dart-define=OWELOOP_TEST_ANON_KEY="$OWELOOP_TEST_ANON_KEY"
journey_status=$?
flutter build apk --debug -t integration_test/recovery_probe_app.dart \
  --dart-define=OWELOOP_TEST_SUPABASE_URL=http://10.0.2.2:55421 \
  --dart-define=OWELOOP_TEST_ANON_KEY="$OWELOOP_TEST_ANON_KEY"
build_status=$?
cd .. || exit 1
probe_status=1
if [ "$build_status" -eq 0 ]; then
  node scripts/test-android-recovery.mjs emulator-5554
  probe_status=$?
fi
if [ "$journey_status" -ne 0 ] || [ "$probe_status" -ne 0 ]; then exit 1; fi
