import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../groups/state/groups_providers.dart';
import '../domain/invitation_models.dart';
import '../state/invitations_providers.dart';
import '../state/invitations_state.dart';

class InvitationInboxScreen extends ConsumerWidget {
  const InvitationInboxScreen({super.key});

  Future<void> _accept(
    BuildContext context,
    WidgetRef ref,
    GroupInvitation invitation,
  ) async {
    final accepted = await ref
        .read(invitationInboxControllerProvider)
        .accept(invitation.id);
    if (!accepted || !context.mounted) return;
    await ref.read(groupsControllerProvider).refresh();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You joined ${invitation.groupName}.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(invitationInboxControllerProvider).state;
    final controller = ref.read(invitationInboxControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitations'),
        actions: [
          IconButton(
            tooltip: 'Refresh invitations',
            onPressed: state.pendingActionId == null
                ? controller.refresh
                : null,
            icon: state.isRefreshing
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: switch (state.status) {
          InvitationInboxStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          InvitationInboxStatus.error when state.invitations.isEmpty =>
            _InboxMessage(
              message:
                  state.errorMessage ?? 'Check your connection and try again.',
              onRetry: controller.refresh,
            ),
          _ => RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              children: [
                Text(
                  'Your group invitations',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Accepting adds you as a regular member. It does not move money or change past group history.',
                ),
                if (state.errorMessage case final message?) ...[
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (state.invitations.isEmpty)
                  const _InboxEmptyState()
                else
                  for (final invitation in state.invitations)
                    _InvitationCard(
                      invitation: invitation,
                      isPending: state.pendingActionId == invitation.id,
                      onAccept: () => _accept(context, ref, invitation),
                      onDecline: () => controller.decline(invitation.id),
                    ),
              ],
            ),
          ),
        },
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.invitation,
    required this.isPending,
    required this.onAccept,
    required this.onDecline,
  });

  final GroupInvitation invitation;
  final bool isPending;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              invitation.groupName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${invitation.currencyCode} group · Invited by ${invitation.inviterDisplayName}',
            ),
            const SizedBox(height: 4),
            Text(
              'Expires ${localizations.formatMediumDate(invitation.expiresAt.toLocal())}',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isPending ? null : onDecline,
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: isPending ? null : onAccept,
                    child: isPending
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxEmptyState extends StatelessWidget {
  const _InboxEmptyState();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'No pending invitations',
    child: Column(
      children: [
        Icon(Icons.mark_email_read_outlined, size: 48),
        SizedBox(height: 12),
        Text('No pending invitations'),
        SizedBox(height: 4),
        Text('When someone invites you to a group, it will appear here.'),
      ],
    ),
  );
}

class _InboxMessage extends StatelessWidget {
  const _InboxMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
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
