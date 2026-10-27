import 'dart:io';
import 'package:flutter/services.dart';

/// flutter_secure_storage 11.2.0 acknowledges Android SharedPreferences.apply
/// before disk completion. The native fence waits for those queued writes off
/// the UI thread. No key, credential or financial payload crosses this channel.
Future<void> flushSecureStorage({
  bool? android,
  MethodChannel channel = const MethodChannel('oweloop/secure_storage'),
}) async {
  if (!(android ?? Platform.isAndroid)) return;
  if (await channel.invokeMethod<bool>('flush') != true) {
    throw StateError('Secure storage persistence was not confirmed.');
  }
}
