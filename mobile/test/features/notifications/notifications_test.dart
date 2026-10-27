import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/features/notifications/notifications.dart';

class TestNotifications implements NotificationsRepository {
  Completer<NotificationPage>? delayed;
  List<NotificationPage> pages = [];
  final List<String> marked = [];
  @override
  Future<NotificationPage> load({
    DateTime? beforeAt,
    String? beforeKey,
    bool unreadOnly = false,
  }) async => delayed != null ? delayed!.future : pages.removeAt(0);
  @override
  Future<void> markRead(String key) async {
    marked.add(key);
  }
}

AppNotification item(String key) => AppNotification(
  key: key,
  groupId: 'group',
  groupName: 'Shared group',
  kind: 'expense_posted',
  at: DateTime.utc(2026),
  isRead: false,
  expenseId: 'expense',
);
void main() {
  test(
    'inbox deduplicates cursor overlaps and persists explicit read state',
    () async {
      final repository = TestNotifications()
        ..pages = [
          NotificationPage(
            [item('a')],
            nextAt: DateTime.utc(2026),
            nextKey: 'a',
          ),
          NotificationPage([item('a'), item('b')]),
        ];
      final controller = NotificationsController(repository);
      await controller.load();
      await controller.load(more: true);
      expect(controller.items.map((value) => value.key), ['a', 'b']);
      await controller.markRead('a');
      expect(repository.marked, ['a']);
      expect(controller.items.first.isRead, isTrue);
      controller.dispose();
    },
  );
  test('account clear discards delayed private results', () async {
    final repository = TestNotifications()
      ..delayed = Completer<NotificationPage>();
    final controller = NotificationsController(repository);
    final pending = controller.load();
    controller.clear();
    repository.delayed!.complete(NotificationPage([item('private')]));
    await pending;
    expect(controller.items, isEmpty);
    expect(controller.loading, isFalse);
    controller.dispose();
  });
}
