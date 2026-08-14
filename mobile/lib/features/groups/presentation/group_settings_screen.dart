import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../domain/group_models.dart';
import '../state/groups_providers.dart';
import '../state/groups_controller.dart';
import '../state/groups_state.dart';
import '../validation/group_validators.dart';

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
                      }
                    },
                    itemBuilder: (_) => [
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
        const SizedBox(height: 32),
        Text('Archive', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          group.isArchived
              ? 'This group is archived. Its history remains available, but it cannot be changed.'
              : 'Archiving preserves all history and stops future financial and membership changes.',
        ),
        const SizedBox(height: 12),
        if (!group.isArchived)
          FilledButton.tonalIcon(
            onPressed: canManage && !state.isManaging
                ? () => onArchive(controller)
                : null,
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Archive group'),
          ),
      ],
    );
  }
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
