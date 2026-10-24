import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:oweloop/features/authentication/data/device_preferences.dart';
import 'package:oweloop/features/expenses/data/expense_draft_store.dart';
import 'package:oweloop/core/operations/financial_operations_providers.dart';
import 'package:oweloop/core/operations/pending_financial_operations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('currency preferences persist and stay isolated by account', () async {
    const storage = FlutterSecureStorage();
    final preferences = SecureDevicePreferences(storage);
    await preferences.setDefaultCurrency('account-a', 'JPY');
    await preferences.setDefaultCurrency('account-b', 'USD');
    expect(
      await SecureDevicePreferences(storage).defaultCurrency('account-a'),
      'JPY',
    );
    await preferences.deleteAccount('account-a');
    expect(await preferences.defaultCurrency('account-a'), isNull);
    expect(await preferences.defaultCurrency('account-b'), 'USD');
    await expectLater(
      preferences.setDefaultCurrency('account-b', 'invented'),
      throwsFormatException,
    );
  });
  test(
    'clearing drafts/preferences cannot erase an uncertain financial request',
    () async {
      const storage = FlutterSecureStorage();
      final drafts = SecureExpenseDraftStore(storage);
      final financial = SecureFinancialOperationStore(storage);
      await financial.write('account-a', [
        PendingFinancialOperation(
          id: 'operation',
          accountId: 'account-a',
          type: 'expense',
          groupId: 'group',
          payload: const {},
          status: FinancialOperationStatus.unknown,
          createdAt: DateTime.utc(2026),
        ),
      ]);
      await drafts.write('account-a', 'group', {'description': 'Unsent'});
      await drafts.write('account-b', 'group', {
        'description': 'Other account',
      });
      await drafts.deleteAccount('account-a');
      await SecureDevicePreferences(storage).deleteAccount('account-a');
      expect(await drafts.read('account-a', 'group'), isNull);
      expect(
        (await drafts.read('account-b', 'group'))!['description'],
        'Other account',
      );
      expect((await financial.read('account-a')).single.unresolved, isTrue);
    },
  );
}
