/// PostgreSQL bigint's positive limit on the supported native mobile targets.
/// Use BigInt for intermediate arithmetic, then check before converting to int.
abstract final class MoneyMath {
  static const maxMinorUnits = 9223372036854775807;
  static final maximum = BigInt.parse('9223372036854775807');

  static BigInt sum(Iterable<int> amounts) =>
      amounts.fold(BigInt.zero, (sum, amount) => sum + BigInt.from(amount));

  static int checked(BigInt amount) {
    if (amount < -maximum || amount > maximum) {
      throw const FormatException('The amount exceeds the supported range.');
    }
    return amount.toInt();
  }
}

class CurrencyRules {
  const CurrencyRules._();

  static const _fractionDigits = <String, int>{
    'AUD': 2,
    'CAD': 2,
    'EUR': 2,
    'GBP': 2,
    'JPY': 0,
    'NZD': 2,
    'SGD': 2,
    'USD': 2,
  };

  static int? fractionDigitsFor(String currencyCode) =>
      _fractionDigits[currencyCode];

  static bool isSupported(String currencyCode) =>
      fractionDigitsFor(currencyCode) != null;
}

class ExactMoney {
  const ExactMoney({required this.currencyCode, required this.minorUnits});

  final String currencyCode;
  final int minorUnits;

  static ExactMoney? tryParse({
    required String text,
    required String currencyCode,
  }) {
    final fractionDigits = CurrencyRules.fractionDigitsFor(currencyCode);
    final normalized = text.trim();
    if (fractionDigits == null || normalized.isEmpty) {
      return null;
    }

    if (fractionDigits == 0) {
      if (!RegExp(r'^\d+$').hasMatch(normalized)) {
        return null;
      }
      final minorUnits = BigInt.tryParse(normalized);
      return minorUnits == null || minorUnits > MoneyMath.maximum
          ? null
          : ExactMoney(
              currencyCode: currencyCode,
              minorUnits: minorUnits.toInt(),
            );
    }

    final match = RegExp(
      '^(\\d+)(?:\\.(\\d{1,$fractionDigits}))?\$',
    ).firstMatch(normalized);
    if (match == null) {
      return null;
    }

    final wholeUnits = BigInt.tryParse(match.group(1)!);
    final fractionText = (match.group(2) ?? '').padRight(fractionDigits, '0');
    final fractionUnits = BigInt.tryParse(fractionText);
    if (wholeUnits == null || fractionUnits == null) {
      return null;
    }

    final scale = _scaleFor(fractionDigits);
    final amount = wholeUnits * BigInt.from(scale) + fractionUnits;
    if (amount > MoneyMath.maximum) return null;
    return ExactMoney(currencyCode: currencyCode, minorUnits: amount.toInt());
  }

  static String formatMinor({
    required String currencyCode,
    required int minorUnits,
  }) {
    final fractionDigits = CurrencyRules.fractionDigitsFor(currencyCode);
    if (fractionDigits == null) {
      throw ArgumentError.value(currencyCode, 'currencyCode', 'Unsupported');
    }

    final sign = minorUnits < 0 ? '-' : '';
    final absoluteMinorUnits = BigInt.from(minorUnits).abs();
    if (fractionDigits == 0) {
      return '$currencyCode $sign$absoluteMinorUnits';
    }

    final scale = BigInt.from(_scaleFor(fractionDigits));
    final wholeUnits = absoluteMinorUnits ~/ scale;
    final fractionUnits = (absoluteMinorUnits % scale).toString().padLeft(
      fractionDigits,
      '0',
    );
    return '$currencyCode $sign$wholeUnits.$fractionUnits';
  }

  String get formatted =>
      formatMinor(currencyCode: currencyCode, minorUnits: minorUnits);

  static int _scaleFor(int fractionDigits) {
    var scale = 1;
    for (var index = 0; index < fractionDigits; index += 1) {
      scale *= 10;
    }
    return scale;
  }
}
