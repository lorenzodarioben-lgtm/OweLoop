import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../authentication/state/authentication_providers.dart';
import '../domain/group_models.dart';
import '../state/groups_providers.dart';
import '../state/groups_state.dart';
import 'group_feedback.dart';

class GroupListScreen extends ConsumerWidget {
  const GroupListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authenticationControllerProvider).state;
    final groupsState = ref.watch(groupsControllerProvider).state;
    final displayName = authState.profile?.displayName ?? 'there';

    return Scaffold(
      appBar: AppBar(
        title: const Text('OweLoop'),
        actions: [
          IconButton(
            tooltip: 'Invitations',
            onPressed: () => context.go(AppRoutes.invitations),
            icon: const Icon(Icons.mail_outline),
          ),
          TextButton(
            onPressed: authState.isSubmitting
                ? null
                : ref.read(authenticationControllerProvider).signOut,
            child: authState.isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign out'),
          ),
        ],
      ),
      floatingActionButton:
          groupsState.status == GroupsStatus.ready &&
              groupsState.groups.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => context.go(AppRoutes.newGroup),
              icon: const Icon(Icons.add),
              label: const Text('Create group'),
            )
          : null,
      body: SafeArea(
        top: false,
        child: switch (groupsState.status) {
          GroupsStatus.loading => const GroupLoadingView(
            label: 'Loading groups',
          ),
          GroupsStatus.error => GroupUnavailableView(
            title: 'We could not load your groups',
            message:
                groupsState.errorMessage ??
                'Check your connection and try again.',
            onRetry: ref.read(groupsControllerProvider).refresh,
          ),
          GroupsStatus.ready => _GroupsContent(
            displayName: displayName,
            groups: groupsState.groups,
            isRefreshing: groupsState.isRefreshing,
          ),
        },
      ),
    );
  }
}

class _GroupsContent extends ConsumerWidget {
  const _GroupsContent({
    required this.displayName,
    required this.groups,
    required this.isRefreshing,
  });

  final String displayName;
  final List<AppGroup> groups;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(groupsControllerProvider);
    if (groups.isEmpty) {
      return RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 64),
            Icon(
              Icons.group_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Hi, $displayName',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a group to start recording shared costs with the people involved.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.newGroup),
              icon: const Icon(Icons.add),
              label: const Text('Create your first group'),
            ),
          ],
        ),
      );
    }

    final activeGroups = groups.where((group) => !group.isArchived).toList();
    final archivedGroups = groups.where((group) => group.isArchived).toList();

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 104),
        children: [
          _GroupsHeading(displayName: displayName, isRefreshing: isRefreshing),
          const SizedBox(height: 16),
          ...activeGroups.map((group) => _GroupListItem(group: group)),
          if (archivedGroups.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Archived groups',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Read-only history for groups that are no longer active.',
            ),
            const SizedBox(height: 8),
            ...archivedGroups.map((group) => _GroupListItem(group: group)),
          ],
        ],
      ),
    );
  }
}

class _GroupListItem extends StatelessWidget {
  const _GroupListItem({required this.group});

  final AppGroup group;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    leading: CircleAvatar(child: Text(group.currencyCode)),
    title: Text(group.name),
    subtitle: Text(
      '${group.currencyCode} · ${group.currentUserRole.label}'
      '${group.isArchived ? ' · Archived' : ''}',
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => context.go(AppRoutes.groupDetailPath(group.id)),
  );
}

class _GroupsHeading extends StatelessWidget {
  const _GroupsHeading({required this.displayName, required this.isRefreshing});

  final String displayName;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your groups',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text('Welcome back, $displayName.'),
            ],
          ),
        ),
        if (isRefreshing)
          const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }
}
