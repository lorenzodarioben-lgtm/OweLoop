import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/app/app_bootstrap.dart';
import 'package:oweloop/features/authentication/state/authentication_providers.dart';
import 'package:oweloop/features/groups/state/groups_providers.dart';
import 'package:oweloop/features/notifications/notifications.dart';
import '../../fakes/authentication_fakes.dart';
import '../../fakes/groups_fakes.dart';

class ScreenNotifications implements NotificationsRepository {
  int reads = 0;
  @override
  Future<NotificationPage> load({
    DateTime? beforeAt,
    String? beforeKey,
    bool unreadOnly = false,
  }) async => NotificationPage([
    AppNotification(
      key: 'expense-key',
      groupId: 'group',
      groupName: 'Shared group',
      kind: 'expense_posted',
      at: DateTime.utc(2026),
      isRead: false,
      expenseId: 'expense',
    ),
  ]);
  @override
  Future<void> markRead(String key) async {
    reads++;
  }
}

void main() {
  testWidgets(
    'inbox is reachable and read actions have visible authoritative feedback',
    (tester) async {
      final repository = ScreenNotifications();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              FakeAuthRepository(restoredUser: testUser),
            ),
            profileRepositoryProvider.overrideWithValue(
              FakeProfileRepository(currentProfile: completedTestProfile),
            ),
            groupsRepositoryProvider.overrideWithValue(FakeGroupsRepository()),
            notificationsRepositoryProvider.overrideWithValue(repository),
          ],
          child: const OweLoopBootstrap(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Account and recovery'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
      expect(find.text('Expense posted · Unread'), findsOneWidget);
      await tester.tap(find.text('Mark read'));
      await tester.pumpAndSettle();
      expect(repository.reads, 1);
      expect(find.text('Expense posted · Read'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
