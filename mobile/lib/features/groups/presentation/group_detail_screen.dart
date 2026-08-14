import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../balances/presentation/group_balance_section.dart';
import '../../expenses/presentation/expense_history_section.dart';
import '../../repayments/presentation/repayment_suggestions_section.dart';
import '../../settlements/presentation/settlement_history_section.dart';
import '../domain/group_models.dart';
import '../state/group_data_refresh_coordinator.dart';
import '../state/groups_providers.dart';
import '../state/groups_state.dart';
import 'add_guest_dialog.dart';
import 'group_feedback.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(groupDetailControllerProvider(groupId));
    final state = ref.watch(groupDetailControllerProvider(groupId)).state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group details'),
        actions:
            state.status == GroupDetailStatus.ready &&
                state.group!.currentUserRole != GroupRole.member
            ? [
                IconButton(
                  tooltip: 'Group settings',
                  onPressed: () =>
                      context.go(AppRoutes.groupSettingsPath(groupId)),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ]
            : null,
      ),
      body: SafeArea(
        top: false,
        child: switch (state.status) {
          GroupDetailStatus.loading => const GroupLoadingView(
            label: 'Loading group',
          ),
          GroupDetailStatus.unavailable => GroupUnavailableView(
            title: 'This group is unavailable',
            message: 'It may no longer be available to you.',
            onRetry: controller.load,
          ),
          GroupDetailStatus.error => GroupUnavailableView(
            title: 'We could not load this group',
            message:
                state.errorMessage ?? 'Check your connection and try again.',
            onRetry: controller.load,
          ),
          GroupDetailStatus.ready => _GroupDetailContent(
            groupId: groupId,
            group: state.group!,
            members: state.members,
          ),
        },
      ),
    );
  }
}

class _GroupDetailContent extends ConsumerWidget {
  const _GroupDetailContent({
    required this.groupId,
    required this.group,
    required this.members,
  });

  final String groupId;
  final AppGroup group;
  final List<GroupMember> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(groupDetailControllerProvider(groupId));
    final refreshCoordinator = ref.read(
      groupDataRefreshCoordinatorProvider((
        groupId: groupId,
        currencyCode: group.currencyCode,
      )),
    );

    return RefreshIndicator(
      onRefresh: refreshCoordinator.refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        itemCount: members.length + 6,
        separatorBuilder: (_, index) =>
            index == 0 ? const SizedBox(height: 24) : const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _GroupSummary(
              group: group,
              onAddGuest:
                  group.currentUserRole.canAddGuests && !group.isArchived
                  ? () {
                      controller.clearError();
                      showDialog<void>(
                        context: context,
                        builder: (_) => AddGuestDialog(groupId: groupId),
                      );
                    }
                  : null,
              onAddExpense: group.isArchived
                  ? null
                  : () => context.go(AppRoutes.newExpensePath(groupId)),
              onRecordSettlement: group.isArchived
                  ? null
                  : () => context.go(AppRoutes.newSettlementPath(groupId)),
            );
          }

          if (index == 1) {
            return GroupBalanceSection(
              groupId: groupId,
              currencyCode: group.currencyCode,
            );
          }

          if (index == 2) {
            return RepaymentSuggestionsSection(group: group);
          }

          if (index == 3) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Members'),
            );
          }

          if (index <= members.length + 3) {
            return _MemberListItem(member: members[index - 4]);
          }

          if (index == members.length + 4) {
            return SettlementHistorySection(
              groupId: groupId,
              currencyCode: group.currencyCode,
            );
          }

          return ExpenseHistorySection(groupId: groupId);
        },
      ),
    );
  }
}

class _GroupSummary extends StatelessWidget {
  const _GroupSummary({
    required this.group,
    required this.onAddGuest,
    required this.onAddExpense,
    required this.onRecordSettlement,
  });

  final AppGroup group;
  final VoidCallback? onAddGuest;
  final VoidCallback? onAddExpense;
  final VoidCallback? onRecordSettlement;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(group.name, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text(group.currencyCode)),
            Chip(label: Text('Your role: ${group.currentUserRole.label}')),
            if (group.isArchived) const Chip(label: Text('Archived')),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: onAddExpense,
              icon: const Icon(Icons.add),
              label: const Text('Add expense'),
            ),
            OutlinedButton.icon(
              onPressed: onRecordSettlement,
              icon: const Icon(Icons.handshake_outlined),
              label: const Text('Record settlement'),
            ),
            if (onAddGuest != null)
              OutlinedButton.icon(
                onPressed: onAddGuest,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Add guest'),
              ),
          ],
        ),
      ],
    );
  }
}

class _MemberListItem extends StatelessWidget {
  const _MemberListItem({required this.member});

  final GroupMember member;

  @override
  Widget build(BuildContext context) {
    final isGuest = member.isGuest;
    final label = isGuest ? 'Guest' : member.role.label;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      leading: CircleAvatar(
        child: Text(member.displayName.characters.first.toUpperCase()),
      ),
      title: Text(member.displayName),
      trailing: Chip(label: Text(label)),
    );
  }
}
