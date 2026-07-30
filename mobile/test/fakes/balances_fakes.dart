import 'package:oweloop/features/balances/data/balances_repository.dart';
import 'package:oweloop/features/balances/domain/balance_models.dart';
import 'package:oweloop/features/expenses/domain/exact_money.dart';
import 'package:oweloop/features/groups/domain/group_models.dart';

class FakeBalancesRepository implements BalancesRepository {
  FakeBalancesRepository({List<GroupBalance>? balances})
    : balances = balances ?? const [testCurrentSettledBalance];

  List<GroupBalance> balances;
  Object? loadBalancesError;
  Future<List<GroupBalance>> Function()? loadBalancesHandler;
  int loadBalancesCalls = 0;
  String? lastGroupId;
  String? lastCurrencyCode;

  @override
  Future<List<GroupBalance>> loadGroupBalances({
    required String groupId,
    required String currencyCode,
  }) async {
    loadBalancesCalls += 1;
    lastGroupId = groupId;
    lastCurrencyCode = currencyCode;
    if (loadBalancesHandler != null) {
      return loadBalancesHandler!();
    }
    if (loadBalancesError != null) {
      throw loadBalancesError!;
    }
    return List<GroupBalance>.from(balances);
  }
}

const testCurrentOwedBalance = GroupBalance(
  groupMemberId: 'owner-member',
  displayName: 'Taylor',
  role: GroupRole.owner,
  isRemoved: false,
  isGuest: false,
  isCurrentUser: true,
  netBalance: ExactMoney(currencyCode: 'AUD', minorUnits: 3000),
);

const testCurrentOwingBalance = GroupBalance(
  groupMemberId: 'owner-member',
  displayName: 'Taylor',
  role: GroupRole.owner,
  isRemoved: false,
  isGuest: false,
  isCurrentUser: true,
  netBalance: ExactMoney(currencyCode: 'AUD', minorUnits: -1250),
);

const testCurrentSettledBalance = GroupBalance(
  groupMemberId: 'owner-member',
  displayName: 'Taylor',
  role: GroupRole.owner,
  isRemoved: false,
  isGuest: false,
  isCurrentUser: true,
  netBalance: ExactMoney(currencyCode: 'AUD', minorUnits: 0),
);

const testGuestOwingBalance = GroupBalance(
  groupMemberId: 'guest-member',
  displayName: 'Morgan',
  role: GroupRole.member,
  isRemoved: false,
  isGuest: true,
  isCurrentUser: false,
  netBalance: ExactMoney(currencyCode: 'AUD', minorUnits: -3000),
);

const testRemovedGuestBalance = GroupBalance(
  groupMemberId: 'removed-guest-member',
  displayName: 'Robin',
  role: GroupRole.member,
  isRemoved: true,
  isGuest: true,
  isCurrentUser: false,
  netBalance: ExactMoney(currencyCode: 'AUD', minorUnits: -200),
);
