import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/guest_claims_providers.dart';
import '../state/guest_claims_state.dart';

class GroupGuestClaimsSection extends ConsumerWidget {
  const GroupGuestClaimsSection({required this.groupId, super.key});

  final String groupId;

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    String claimRequestId,
    String guestDisplayName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoke claim request?'),
        content: Text(
          'This will stop the pending account claim for $guestDisplayName.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Revoke request'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref
          .read(groupGuestClaimsControllerProvider(groupId))
          .revoke(claimRequestId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(groupGuestClaimsControllerProvider(groupId)).state;
    final controller = ref.read(groupGuestClaimsControllerProvider(groupId));
    final localizations = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Guest account claims',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Use “Request account claim” on a guest above. They must already have an account and explicitly accept. If they register later, revoke and resend the request.',
        ),
        if (state.errorMessage case final message?) ...[
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (state.successMessage case final message?) ...[
          const SizedBox(height: 12),
          Text(message),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Pending requests',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Refresh guest claim requests',
              onPressed: state.isBusy ? null : controller.load,
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
        if (state.status == GroupGuestClaimsStatus.loading)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (state.claimRequests.isEmpty)
          const Text('There are no pending guest account claims.')
        else
          for (final claimRequest in state.claimRequests)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(claimRequest.guestDisplayName),
              subtitle: Text(
                '${claimRequest.recipientEmail} · Expires ${localizations.formatMediumDate(claimRequest.expiresAt.toLocal())}',
              ),
              trailing: TextButton(
                onPressed: state.isBusy
                    ? null
                    : () => _revoke(
                        context,
                        ref,
                        claimRequest.id,
                        claimRequest.guestDisplayName,
                      ),
                child: state.revokingClaimRequestId == claimRequest.id
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Revoke'),
              ),
            ),
      ],
    );
  }
}
