import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../guest_claims/presentation/guest_claim_dialog.dart';
import '../../guest_claims/presentation/group_guest_claims_section.dart';
import '../../invitations/presentation/group_invitations_section.dart';
import '../domain/group_models.dart';
import '../state/groups_providers.dart';
import '../state/groups_controller.dart';
import '../state/groups_state.dart';
import '../validation/group_validators.dart';

final groupLifecycleProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, id) {
      ref.watch(groupDetailControllerProvider(id));
      return ref.watch(groupsRepositoryProvider).loadLifecycleEvents(id);
    });

class GroupSettingsScreen extends ConsumerStatefulWidget {
  const GroupSettingsScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<GroupSettingsScreen> createState() =>
      _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _initialize(AppGroup group) {
    if (_initialized) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialized) return;
      setState(() {
        _nameController.text = group.name;
        _initialized = true;
      });
    });
  }

  Future<void> _rename(GroupDetailController controller) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await controller.rename(GroupRenameInput(name: _nameController.text));
  }

  Future<void> _archive(GroupDetailController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive group?'),
        content: const Text(
          'History stays visible, but no new expenses, settlements, or member changes can be made.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Archive group'),
          ),
        ],
      ),
    );
    if (confirmed == true && await controller.archive() && mounted) {
      await ref.read(groupsControllerProvider).refresh();
      if (mounted) context.go(AppRoutes.home);
    }
  }

  Future<void> _reopen(GroupDetailController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reopen group?'),
        content: const Text(
          'Balances and history stay unchanged. Members can record external settlements and new expenses again. This action is audited.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reopen group'),
          ),
        ],
      ),
    );
    if (confirmed == true && await controller.reopen()) {
      ref.invalidate(groupLifecycleProvider(widget.groupId));
      await ref.read(groupsControllerProvider).refresh();
    }
  }

  Future<void> _remove(
    GroupDetailController controller,
    GroupMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${member.displayName}?'),
        content: const Text(
          'Their existing expenses and balances will remain in the group history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove member'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.removeMember(member.id);
  }

  Future<void> _transferOwnership(
    GroupDetailController controller,
    GroupMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Transfer ownership to ${member.displayName}?'),
        content: const Text(
          'You will become an administrator. The new owner will manage the group from then on.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Transfer ownership'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.transferOwnership(member.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref
        .watch(groupDetailControllerProvider(widget.groupId))
        .state;
    final controller = ref.read(groupDetailControllerProvider(widget.groupId));
    return Scaffold(
      appBar: AppBar(title: const Text('Group settings')),
      body: SafeArea(
        top: false,
        child: switch (state.status) {
          GroupDetailStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          GroupDetailStatus.unavailable => _SettingsMessage(
            message: 'This group is unavailable.',
            onRetry: controller.load,
          ),
          GroupDetailStatus.error => _SettingsMessage(
            message:
                state.errorMessage ?? 'Check your connection and try again.',
            onRetry: controller.load,
          ),
          GroupDetailStatus.ready => _SettingsContent(
            state: state,
            controller: controller,
            formKey: _formKey,
            nameController: _nameController,
            onReady: _initialize,
            onRename: _rename,
            onArchive: _archive,
            onReopen: _reopen,
            onRemove: _remove,
            onTransferOwnership: _transferOwnership,
          ),
        },
      ),
    );
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent({
    required this.state,
    required this.controller,
    required this.formKey,
    required this.nameController,
    required this.onReady,
    required this.onRename,
    required this.onArchive,
    required this.onReopen,
    required this.onRemove,
    required this.onTransferOwnership,
  });

  final GroupDetailState state;
  final GroupDetailController controller;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final ValueChanged<AppGroup> onReady;
  final Future<void> Function(GroupDetailController) onRename;
  final Future<void> Function(GroupDetailController) onArchive;
  final Future<void> Function(GroupDetailController) onReopen;
  final Future<void> Function(GroupDetailController, GroupMember) onRemove;
  final Future<void> Function(GroupDetailController, GroupMember)
  onTransferOwnership;

  @override
  Widget build(BuildContext context) {
    final group = state.group!;
    onReady(group);
    final isOwner = group.currentUserRole == GroupRole.owner;
    final canManage =
        group.currentUserRole != GroupRole.member && !group.isArchived;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        Text('Group details', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('Currency: ${group.currencyCode} - fixed for this group'),
        const SizedBox(height: 16),
        if (state.errorMessage case final message?) ...[
          Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 12),
        ],
        Form(
          key: formKey,
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Group name'),
                  validator: GroupValidators.groupName,
                  enabled: canManage && !state.isManaging,
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: canManage && !state.isManaging
                    ? () => onRename(controller)
                    : null,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text('Members', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final member in state.members)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              child: Text(member.displayName.characters.first.toUpperCase()),
            ),
            title: Text(member.displayName),
            subtitle: Text(member.isGuest ? 'Guest' : member.role.label),
            trailing: canManage && member.role != GroupRole.owner
                ? PopupMenuButton<String>(
                    onSelected: (action) async {
                      switch (action) {
                        case 'remove':
                          await onRemove(controller, member);
                        case 'promote':
                          await controller.setMemberRole(
                            member.id,
                            GroupRole.admin,
                          );
                        case 'demote':
                          await controller.setMemberRole(
                            member.id,
                            GroupRole.member,
                          );
                        case 'transfer':
                          await onTransferOwnership(controller, member);
                        case 'claim':
                          await showDialog<void>(
                            context: context,
                            builder: (_) => GuestClaimDialog(
                              groupId: group.id,
                              guest: member,
                            ),
                          );
                      }
                    },
                    itemBuilder: (_) => [
                      if (member.isGuest)
                        const PopupMenuItem(
                          value: 'claim',
                          child: Text('Request account claim'),
                        ),
                      if (isOwner &&
                          !member.isGuest &&
                          member.role == GroupRole.member)
                        const PopupMenuItem(
                          value: 'promote',
                          child: Text('Make admin'),
                        ),
                      if (isOwner && member.role == GroupRole.admin)
                        const PopupMenuItem(
                          value: 'demote',
                          child: Text('Remove admin role'),
                        ),
                      if (isOwner && !member.isGuest)
                        const PopupMenuItem(
                          value: 'transfer',
                          child: Text('Transfer ownership'),
                        ),
                      const PopupMenuItem(
                        value: 'remove',
                        child: Text('Remove member'),
                      ),
                    ],
                  )
                : null,
          ),
        if (canManage) ...[
          const SizedBox(height: 32),
          GroupInvitationsSection(groupId: group.id),
          const SizedBox(height: 32),
          GroupGuestClaimsSection(groupId: group.id),
        ],
        const SizedBox(height: 32),
        Text('Archive', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          group.isArchived
              ? 'This group is archived. The owner can reopen it to resolve outstanding balances. If there is no registered owner, contact support for audited recovery to an existing member.'
              : 'Archiving preserves all history and stops future financial and membership changes.',
        ),
        const SizedBox(height: 12),
        if (!group.isArchived)
          Semantics(
            button: true,
            label: 'Archive group and make its history read only',
            child: FilledButton.tonalIcon(
              onPressed: canManage && !state.isManaging
                  ? () => onArchive(controller)
                  : null,
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Archive group'),
            ),
          ),
        if (group.isArchived && isOwner)
          FilledButton(
            onPressed: state.isManaging ? null : () => onReopen(controller),
            child: const Text('Reopen group'),
          ),
        const SizedBox(height: 24),
        const Text('Recent group lifecycle history'),
        _LifecycleHistory(groupId: group.id),
      ],
    );
  }
}

class _LifecycleHistory extends ConsumerWidget {
  const _LifecycleHistory({required this.groupId});
  final String groupId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(groupLifecycleProvider(groupId))
      .when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => TextButton(
          onPressed: () => ref.invalidate(groupLifecycleProvider(groupId)),
          child: const Text('Retry group history'),
        ),
        data: (events) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (events.isEmpty)
              const Text('No recorded lifecycle changes yet.'),
            for (final event in events)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(switch (event['event_type']) {
                  'archived' => 'Group archived',
                  'reopened' => 'Group reopened',
                  _ => 'Ownerless group recovered by operator',
                }),
                subtitle: Text(
                  '${event['created_at']}\n${event['reason'] ?? ''}',
                ),
              ),
          ],
        ),
      );
}

class _SettingsMessage extends StatelessWidget {
  const _SettingsMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}
