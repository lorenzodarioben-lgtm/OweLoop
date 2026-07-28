class GroupValidators {
  const GroupValidators._();

  static const int maximumGroupNameLength = 120;
  static const int maximumGuestNameLength = 80;
  static const supportedCurrencies = <String>[
    'AUD',
    'CAD',
    'EUR',
    'GBP',
    'JPY',
    'NZD',
    'SGD',
    'USD',
  ];

  static String? groupName(String? value) {
    final trimmedValue = value?.trim() ?? '';
    if (trimmedValue.isEmpty) {
      return 'Enter a group name.';
    }
    if (trimmedValue.length > maximumGroupNameLength) {
      return 'Use $maximumGroupNameLength characters or fewer.';
    }
    return null;
  }

  static String? currency(String? value) {
    if (value == null || !supportedCurrencies.contains(value)) {
      return 'Choose a currency.';
    }
    return null;
  }

  static String? guestName(String? value) {
    final trimmedValue = value?.trim() ?? '';
    if (trimmedValue.isEmpty) {
      return 'Enter a guest name.';
    }
    if (trimmedValue.length > maximumGuestNameLength) {
      return 'Use $maximumGuestNameLength characters or fewer.';
    }
    return null;
  }
}
