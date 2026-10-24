import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/router.dart';
import 'notifications.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(notificationsControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Refresh notifications',
            onPressed: () => controller.load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Unread only'),
            value: controller.unreadOnly,
            onChanged: controller.filter,
          ),
          if (controller.loading) const LinearProgressIndicator(),
          if (controller.error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(controller.error!),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => controller.load(),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                itemCount: controller.items.length + 1,
                itemBuilder: (context, index) {
                  if (index == controller.items.length) {
                    return controller.hasMore
                        ? TextButton(
                            onPressed: controller.loading
                                ? null
                                : () => controller.load(more: true),
                            child: const Text('Load older activity'),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              controller.items.isEmpty
                                  ? 'No notifications match this view.'
                                  : 'End of activity.',
                            ),
                          );
                  }
                  final item = controller.items[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.label} · ${item.isRead ? 'Read' : 'Unread'}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(item.groupName),
                        Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatMediumDate(item.at.toLocal()),
                        ),
                        Wrap(
                          children: [
                            TextButton(
                              onPressed: () {
                                final path = switch (item.kind) {
                                  'invitation' => AppRoutes.invitations,
                                  'guest_claim' => AppRoutes.guestClaims,
                                  _ when item.expenseId != null =>
                                    AppRoutes.expenseDetailPath(
                                      item.groupId,
                                      item.expenseId!,
                                    ),
                                  _ when item.kind.startsWith('settlement') =>
                                    AppRoutes.settlementHistoryPath(
                                      item.groupId,
                                    ),
                                  _ => AppRoutes.groupDetailPath(item.groupId),
                                };
                                context.push(path);
                              },
                              child: const Text('Open'),
                            ),
                            if (!item.isRead)
                              TextButton(
                                onPressed: controller.marking.contains(item.key)
                                    ? null
                                    : () => controller.markRead(item.key),
                                child: const Text('Mark read'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
