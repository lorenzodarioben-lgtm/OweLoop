import '../../balances/domain/balance_models.dart';
import '../../expenses/domain/exact_money.dart';

class RepaymentSuggestion {
  const RepaymentSuggestion({
    required this.payingMember,
    required this.receivingMember,
    required this.amount,
  });

  final GroupBalance payingMember;
  final GroupBalance receivingMember;
  final ExactMoney amount;

  bool get involvesRemovedMember =>
      payingMember.isRemoved || receivingMember.isRemoved;

  String get statement =>
      '${payingMember.displayName} pays ${receivingMember.displayName}';
}

abstract final class DebtSimplifier {
  static List<RepaymentSuggestion> suggest(Iterable<GroupBalance> balances) {
    final entries = balances.toList();
    if (entries.isEmpty) return const [];

    final currencyCodes = entries
        .map((balance) => balance.netBalance.currencyCode)
        .toSet();
    if (currencyCodes.length != 1) {
      throw const FormatException('Balances use different currencies.');
    }

    final total = entries.fold<int>(
      0,
      (sum, balance) => sum + balance.netBalance.minorUnits,
    );
    if (total != 0) {
      throw const FormatException('Balances do not reconcile.');
    }

    final debtors =
        entries
            .where((balance) => balance.netBalance.minorUnits < 0)
            .map(
              (balance) => _OutstandingBalance(
                balance: balance,
                remainingMinorUnits: -balance.netBalance.minorUnits,
              ),
            )
            .toList()
          ..sort(_compareOutstanding);
    final creditors =
        entries
            .where((balance) => balance.netBalance.minorUnits > 0)
            .map(
              (balance) => _OutstandingBalance(
                balance: balance,
                remainingMinorUnits: balance.netBalance.minorUnits,
              ),
            )
            .toList()
          ..sort(_compareOutstanding);

    final suggestions = <RepaymentSuggestion>[];
    var debtorIndex = 0;
    var creditorIndex = 0;
    while (debtorIndex < debtors.length && creditorIndex < creditors.length) {
      final debtor = debtors[debtorIndex];
      final creditor = creditors[creditorIndex];
      final amountMinorUnits =
          debtor.remainingMinorUnits < creditor.remainingMinorUnits
          ? debtor.remainingMinorUnits
          : creditor.remainingMinorUnits;

      suggestions.add(
        RepaymentSuggestion(
          payingMember: debtor.balance,
          receivingMember: creditor.balance,
          amount: ExactMoney(
            currencyCode: debtor.balance.netBalance.currencyCode,
            minorUnits: amountMinorUnits,
          ),
        ),
      );
      debtor.remainingMinorUnits -= amountMinorUnits;
      creditor.remainingMinorUnits -= amountMinorUnits;
      if (debtor.remainingMinorUnits == 0) debtorIndex += 1;
      if (creditor.remainingMinorUnits == 0) creditorIndex += 1;
    }
    return List.unmodifiable(suggestions);
  }

  static int _compareOutstanding(
    _OutstandingBalance first,
    _OutstandingBalance second,
  ) {
    final amountOrder = second.remainingMinorUnits.compareTo(
      first.remainingMinorUnits,
    );
    if (amountOrder != 0) return amountOrder;
    final nameOrder = first.balance.displayName.compareTo(
      second.balance.displayName,
    );
    if (nameOrder != 0) return nameOrder;
    return first.balance.groupMemberId.compareTo(second.balance.groupMemberId);
  }
}

class _OutstandingBalance {
  _OutstandingBalance({
    required this.balance,
    required this.remainingMinorUnits,
  });

  final GroupBalance balance;
  int remainingMinorUnits;
}
