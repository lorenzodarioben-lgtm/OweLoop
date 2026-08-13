import '../../expenses/domain/exact_money.dart';
import '../../groups/domain/group_models.dart';

enum BalancePosition {
  owed,
  owing,
  settled;

  String get memberVerb => switch (this) {
    BalancePosition.owed => 'is owed',
    BalancePosition.owing => 'owes',
    BalancePosition.settled => 'is settled up',
  };
}

class GroupBalance {
  const GroupBalance({
    required this.groupMemberId,
    required this.displayName,
    required this.role,
    required this.isRemoved,
    required this.isGuest,
    required this.isCurrentUser,
    required this.netBalance,
  });

  final String groupMemberId;
  final String displayName;
  final GroupRole role;
  final bool isRemoved;
  final bool isGuest;
  final bool isCurrentUser;
  final ExactMoney netBalance;

  BalancePosition get position {
    if (netBalance.minorUnits > 0) {
      return BalancePosition.owed;
    }
    if (netBalance.minorUnits < 0) {
      return BalancePosition.owing;
    }
    return BalancePosition.settled;
  }

  ExactMoney get absoluteBalance => ExactMoney(
    currencyCode: netBalance.currencyCode,
    minorUnits: netBalance.minorUnits.abs(),
  );

  String get memberStatement => switch (position) {
    BalancePosition.owed => '$displayName is owed ${absoluteBalance.formatted}',
    BalancePosition.owing => '$displayName owes ${absoluteBalance.formatted}',
    BalancePosition.settled => '$displayName is settled up',
  };

  factory GroupBalance.fromMap(
    Map<String, dynamic> map, {
    required String currencyCode,
  }) {
    return GroupBalance(
      groupMemberId: map['group_member_id'] as String,
      displayName: map['display_name'] as String,
      role: GroupRole.fromDatabase(map['role']),
      isRemoved: map['is_removed'] as bool? ?? false,
      isGuest: map['is_guest'] as bool? ?? false,
      isCurrentUser: map['is_current_user'] as bool? ?? false,
      netBalance: ExactMoney(
        currencyCode: currencyCode,
        minorUnits: _minorUnitsFrom(map['net_balance_minor']),
      ),
    );
  }

  static List<GroupBalance> ordered(Iterable<GroupBalance> balances) {
    final orderedBalances = balances.toList();
    orderedBalances.sort((first, second) {
      if (first.isCurrentUser != second.isCurrentUser) {
        return first.isCurrentUser ? -1 : 1;
      }
      if (first.isRemoved != second.isRemoved) {
        return first.isRemoved ? 1 : -1;
      }
      final displayNameOrder = first.displayName.compareTo(second.displayName);
      if (displayNameOrder != 0) {
        return displayNameOrder;
      }
      return first.groupMemberId.compareTo(second.groupMemberId);
    });
    return orderedBalances;
  }
}

class GroupBalanceSummary {
  const GroupBalanceSummary({required this.currentUserBalance});

  final GroupBalance currentUserBalance;

  factory GroupBalanceSummary.fromBalances(Iterable<GroupBalance> balances) {
    final currentUserBalances = balances
        .where((balance) => balance.isCurrentUser)
        .toList();
    if (currentUserBalances.length != 1) {
      throw const FormatException(
        'A group balance result must include one current member.',
      );
    }
    return GroupBalanceSummary(currentUserBalance: currentUserBalances.single);
  }

  String get statement => switch (currentUserBalance.position) {
    BalancePosition.owed =>
      'You are owed ${currentUserBalance.absoluteBalance.formatted}',
    BalancePosition.owing =>
      'You owe ${currentUserBalance.absoluteBalance.formatted}',
    BalancePosition.settled => 'You are settled up',
  };
}

int _minorUnitsFrom(Object? value) {
  return switch (value) {
    int minorUnits => minorUnits,
    String minorUnits =>
      int.tryParse(minorUnits) ??
          (throw const FormatException('The balance amount is unavailable.')),
    _ => throw const FormatException('The balance amount is unavailable.'),
  };
}
