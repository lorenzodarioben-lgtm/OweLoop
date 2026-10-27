import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../authentication/state/authentication_providers.dart';

class AppNotification {
  const AppNotification({
    required this.key,
    required this.groupId,
    required this.groupName,
    required this.kind,
    required this.at,
    required this.isRead,
    this.expenseId,
  });
  final String key, groupId, groupName, kind;
  final DateTime at;
  final bool isRead;
  final String? expenseId;
  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
    key: map['notification_key'] as String,
    groupId: map['group_id'] as String,
    groupName: map['group_name'] as String,
    kind: map['kind'] as String,
    at: DateTime.parse(map['occurred_at'] as String),
    isRead: map['is_read'] as bool,
    expenseId: map['expense_id'] as String?,
  );
  AppNotification read() => AppNotification(
    key: key,
    groupId: groupId,
    groupName: groupName,
    kind: kind,
    at: at,
    isRead: true,
    expenseId: expenseId,
  );
  String get label => switch (kind) {
    'invitation' => 'Group invitation',
    'guest_claim' => 'Guest claim request',
    'expense_posted' => 'Expense posted',
    'expense_voided' => 'Expense voided',
    'settlement_recorded' => 'External settlement recorded',
    'settlement_voided' => 'Settlement voided',
    'group_archived' => 'Group archived',
    'group_reopened' => 'Group reopened',
    'group_operator_recovered' => 'Ownerless group recovered',
    _ => 'Group activity',
  };
}

class NotificationPage {
  const NotificationPage(this.items, {this.nextAt, this.nextKey});
  final List<AppNotification> items;
  final DateTime? nextAt;
  final String? nextKey;
}

abstract interface class NotificationsRepository {
  Future<NotificationPage> load({
    DateTime? beforeAt,
    String? beforeKey,
    bool unreadOnly = false,
  });
  Future<void> markRead(String key);
}

class SupabaseNotificationsRepository implements NotificationsRepository {
  SupabaseNotificationsRepository(this.client);
  final SupabaseClient client;
  @override
  Future<NotificationPage> load({
    DateTime? beforeAt,
    String? beforeKey,
    bool unreadOnly = false,
  }) async {
    final rows = await client.rpc(
      'get_notification_page',
      params: {
        'p_limit': 50,
        'p_before_at': beforeAt?.toUtc().toIso8601String(),
        'p_before_key': beforeKey,
        'p_unread_only': unreadOnly,
      },
    );
    final all = (rows as List)
        .map(
          (dynamic row) =>
              AppNotification.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
    final items = all.take(50).toList();
    final last = items.isEmpty ? null : items.last;
    return NotificationPage(
      items,
      nextAt: all.length > 50 ? last?.at : null,
      nextKey: all.length > 50 ? last?.key : null,
    );
  }

  @override
  Future<void> markRead(String key) async {
    await client.rpc(
      'mark_notification_read',
      params: {'p_notification_key': key},
    );
  }
}

class NotificationsController extends ChangeNotifier {
  NotificationsController(this.repository);
  final NotificationsRepository repository;
  List<AppNotification> items = [];
  bool loading = false, unreadOnly = false, hasMore = false;
  String? error;
  DateTime? _nextAt;
  String? _nextKey;
  int _generation = 0;
  int _sessionGeneration = 0;
  bool _disposed = false;
  final Set<String> marking = {};
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> filter(bool unread) async {
    unreadOnly = unread;
    items = [];
    await load();
  }

  Future<void> load({bool more = false}) async {
    if (more && (loading || !hasMore)) return;
    final generation = more ? _generation : ++_generation;
    loading = true;
    error = null;
    _notify();
    try {
      final page = await repository.load(
        beforeAt: more ? _nextAt : null,
        beforeKey: more ? _nextKey : null,
        unreadOnly: unreadOnly,
      );
      if (generation != _generation || _disposed) return;
      final seen = more ? items.map((value) => value.key).toSet() : <String>{};
      items = [
        if (more) ...items,
        ...page.items.where((value) => seen.add(value.key)),
      ];
      _nextAt = page.nextAt;
      _nextKey = page.nextKey;
      hasMore = _nextKey != null;
    } catch (_) {
      if (generation == _generation) {
        error =
            'Could not refresh notifications. Displayed activity may be stale; check your connection and retry.';
      }
    } finally {
      if (generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> markRead(String key) async {
    if (!marking.add(key)) return;
    final generation = _sessionGeneration;
    _notify();
    try {
      await repository.markRead(key);
      if (generation != _sessionGeneration || _disposed) return;
      items = [
        for (final item in items)
          if (item.key != key || !unreadOnly)
            item.key == key ? item.read() : item,
      ];
    } catch (_) {
      if (generation == _sessionGeneration) {
        error = 'Read status could not be saved. Retry after reconnecting.';
      }
    } finally {
      if (generation == _sessionGeneration) {
        marking.remove(key);
        _notify();
      }
    }
  }

  void clear() {
    _generation++;
    _sessionGeneration++;
    items = [];
    error = null;
    loading = false;
    hasMore = false;
    _nextAt = null;
    _nextKey = null;
    marking.clear();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _sessionGeneration++;
    super.dispose();
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => SupabaseNotificationsRepository(Supabase.instance.client),
);
final notificationsControllerProvider =
    ChangeNotifierProvider.autoDispose<NotificationsController>((ref) {
      final controller = NotificationsController(
        ref.watch(notificationsRepositoryProvider),
      );
      ref.listen(
        authenticationControllerProvider.select(
          (value) => value.state.user?.id,
        ),
        (_, id) {
          controller.clear();
          if (id != null) unawaited(controller.load());
        },
        fireImmediately: true,
      );
      return controller;
    });
