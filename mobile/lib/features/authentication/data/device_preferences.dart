import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../expenses/domain/exact_money.dart';

abstract interface class DevicePreferences {
  Future<String?> defaultCurrency(String accountId);
  Future<void> setDefaultCurrency(String accountId, String? currency);
  Future<void> deleteAccount(String accountId);
}

class SecureDevicePreferences implements DevicePreferences {
  SecureDevicePreferences(this.storage);
  final FlutterSecureStorage storage;
  String _key(String account) =>
      'oweloop.preferences.v1.$account.default_currency';
  @override
  Future<String?> defaultCurrency(String accountId) async {
    final value = await storage.read(key: _key(accountId));
    if (value != null && !CurrencyRules.isSupported(value)) {
      throw const FormatException('Unsupported default currency.');
    }
    return value;
  }

  @override
  Future<void> setDefaultCurrency(String accountId, String? currency) async {
    if (currency == null) {
      await deleteAccount(accountId);
      return;
    }
    if (!CurrencyRules.isSupported(currency)) {
      throw const FormatException('Unsupported default currency.');
    }
    await storage.write(key: _key(accountId), value: currency);
  }

  @override
  Future<void> deleteAccount(String accountId) =>
      storage.delete(key: _key(accountId));
}

final devicePreferencesProvider = Provider<DevicePreferences>(
  (ref) => SecureDevicePreferences(const FlutterSecureStorage()),
);
