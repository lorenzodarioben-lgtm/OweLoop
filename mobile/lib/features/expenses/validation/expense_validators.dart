import '../domain/exact_money.dart';

class ExpenseValidators {
  const ExpenseValidators._();

  static String? description(String? value) {
    final trimmedValue = value?.trim() ?? '';
    if (trimmedValue.isEmpty) {
      return 'Enter an expense description.';
    }
    if (trimmedValue.length > 500) {
      return 'Use 500 characters or fewer.';
    }
    return null;
  }

  static String? amount(String? value, String currencyCode) {
    final money = ExactMoney.tryParse(
      text: value ?? '',
      currencyCode: currencyCode,
    );
    if (money == null) {
      final fractionDigits = CurrencyRules.fractionDigitsFor(currencyCode);
      if (fractionDigits == 0) {
        return 'Enter a whole-number amount.';
      }
      return 'Enter an amount with up to $fractionDigits decimal places.';
    }
    if (money.minorUnits <= 0) {
      return 'Enter an amount greater than zero.';
    }
    return null;
  }
}
