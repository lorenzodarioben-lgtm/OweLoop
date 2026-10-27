import 'package:oweloop/features/authentication/data/device_preferences.dart';

class MemoryDevicePreferences implements DevicePreferences {
  final Map<String, String> values = {};
  Future<String?> Function(String)? loader;
  @override
  Future<String?> defaultCurrency(String accountId) async =>
      loader != null ? loader!(accountId) : values[accountId];
  @override
  Future<void> setDefaultCurrency(String accountId, String? currency) async {
    if (currency == null) {
      values.remove(accountId);
    } else {
      values[accountId] = currency;
    }
  }

  @override
  Future<void> deleteAccount(String accountId) async {
    values.remove(accountId);
  }
}
