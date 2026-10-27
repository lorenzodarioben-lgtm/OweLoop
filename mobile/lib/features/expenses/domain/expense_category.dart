enum ExpenseCategory {
  food('Food and drinks'),
  groceries('Groceries'),
  transport('Transport'),
  accommodation('Accommodation'),
  utilities('Utilities'),
  shopping('Shopping'),
  entertainment('Entertainment'),
  travel('Travel'),
  household('Household'),
  healthcare('Healthcare'),
  other('Other');

  const ExpenseCategory(this.label);
  final String label;
  static ExpenseCategory? fromKey(Object? key) {
    if (key == null) return null;
    return values.firstWhere(
      (value) => value.name == key,
      orElse: () =>
          throw const FormatException('Unsupported expense category.'),
    );
  }
}
