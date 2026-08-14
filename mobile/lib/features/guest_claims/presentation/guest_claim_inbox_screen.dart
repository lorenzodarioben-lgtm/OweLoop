import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../groups/state/group_data_refresh_coordinator.dart';
import '../domain/guest_claim_models.dart';
import '../state/guest_claims_providers.dart';
import '../state/guest_claims_state.dart';

class GuestClaimInboxScreen extends ConsumerWidget {
  const GuestClaimInboxScreen({super.key});

  Future<void> _accept(
    BuildContext context,
    WidgetRef ref,
    GuestClaimRequest claimRequest,
  ) async {
    final accepted = await ref
        .read(guestClaimInboxControllerProvider)
        .accept(claimRequest.id);
    if (!accepted || !context.mounted) return;
    await ref
        .read(
          groupDataRefreshCoordinatorProvider((
            groupId: claimRequest.groupId,
            currencyCode: claimRequest.currencyCode,
          )),
        )
        .refresh();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${claimRequest.guestDisplayName} is now linked to your account.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(guestClaimInboxControllerProvider).state;
    final controller = ref.read(guestClaimInboxControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guest claim requests'),
        actions: [
          IconButton(
            tooltip: 'Refresh guest claim requests',
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
          GuestClaimInboxStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          GuestClaimInboxStatus.error when state.claimRequests.isEmpty =>
            _ClaimMessage(
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
                  'Claim a guest history',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Accept only if this guest represents you. Your existing group history, balances, and member ID remain exactly as recorded.',
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
                if (state.claimRequests.isEmpty)
                  const _ClaimEmptyState()
                else
                  for (final claimRequest in state.claimRequests)
                    _GuestClaimCard(
                      claimRequest: claimRequest,
                      isPending: state.pendingActionId == claimRequest.id,
                      onAccept: () => _accept(context, ref, claimRequest),
                      onDecline: () => controller.decline(claimRequest.id),
                    ),
              ],
            ),
          ),
        },
      ),
    );
  }
}

class _GuestClaimCard extends StatelessWidget {
  const _GuestClaimCard({
    required this.claimRequest,
    required this.isPending,
    required this.onAccept,
    required this.onDecline,
  });

  final GuestClaimRequest claimRequest;
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
              claimRequest.guestDisplayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('${claimRequest.groupName} · ${claimRequest.currencyCode}'),
            const SizedBox(height: 4),
            Text('Requested by ${claimRequest.initiatedByDisplayName}'),
            const SizedBox(height: 4),
            Text(
              'Expires ${localizations.formatMediumDate(claimRequest.expiresAt.toLocal())}',
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
                        : const Text('Accept claim'),
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

class _ClaimEmptyState extends StatelessWidget {
  const _ClaimEmptyState();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'No pending guest claim requests',
    child: const Column(
      children: [
        Icon(Icons.person_search_outlined, size: 48),
        SizedBox(height: 12),
        Text('No pending guest claim requests'),
        SizedBox(height: 4),
        Text('A group owner or administrator must request a claim first.'),
      ],
    ),
  );
}

class _ClaimMessage extends StatelessWidget {
  const _ClaimMessage({required this.message, required this.onRetry});

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
