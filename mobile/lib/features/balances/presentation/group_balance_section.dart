import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/balance_models.dart';
import '../state/balances_providers.dart';
import '../state/balances_state.dart';

class GroupBalanceSection extends ConsumerWidget {
  const GroupBalanceSection({
    required this.groupId,
    required this.currencyCode,
    super.key,
  });

  final String groupId;
  final String currencyCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = (groupId: groupId, currencyCode: currencyCode);
    final controller = ref.read(groupBalancesControllerProvider(request));
    final state = ref.watch(groupBalancesControllerProvider(request)).state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Balances',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Refresh balances',
              onPressed: state.isRefreshing ? null : controller.refresh,
              icon: state.isRefreshing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        switch (state.status) {
          GroupBalancesStatus.loading => const _BalanceLoading(),
          GroupBalancesStatus.unavailable => _BalanceUnavailable(
            onRetry: controller.refresh,
          ),
          GroupBalancesStatus.error => _BalanceError(
            message:
                state.errorMessage ?? 'Check your connection and try again.',
            onRetry: controller.refresh,
          ),
          GroupBalancesStatus.ready => _BalanceResults(
            summary: state.summary!,
            balances: state.balances,
          ),
        },
      ],
    );
  }
}

class _BalanceResults extends StatelessWidget {
  const _BalanceResults({required this.summary, required this.balances});

  final GroupBalanceSummary summary;
  final List<GroupBalance> balances;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Your balance: ${summary.statement}',
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your balance',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary.statement,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Member balances', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text('Posted expenses and recorded settlements are included.'),
        const SizedBox(height: 8),
        for (final balance in balances) _BalanceListItem(balance: balance),
      ],
    );
  }
}

class _BalanceListItem extends StatelessWidget {
  const _BalanceListItem({required this.balance});

  final GroupBalance balance;

  @override
  Widget build(BuildContext context) {
    final label = switch (balance.position) {
      BalancePosition.owed => 'Owed',
      BalancePosition.owing => 'Owes',
      BalancePosition.settled => 'Settled',
    };
    return ListTile(
      isThreeLine: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        child: Text(balance.displayName.characters.first.toUpperCase()),
      ),
      title: Text(
        balance.isCurrentUser
            ? '${balance.displayName} (You)'
            : balance.displayName,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(balance.memberStatement),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: [
              Chip(label: Text(label), visualDensity: VisualDensity.compact),
              if (balance.isGuest)
                const Chip(
                  label: Text('Guest'),
                  visualDensity: VisualDensity.compact,
                ),
              if (balance.isRemoved)
                const Chip(
                  label: Text('Removed'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
      trailing: Text(
        balance.absoluteBalance.formatted,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}

class _BalanceLoading extends StatelessWidget {
  const _BalanceLoading();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      label: 'Loading balances',
      child: Column(
        children: List.generate(
          3,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BalanceUnavailable extends StatelessWidget {
  const _BalanceUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _BalanceMessage(
      message: 'This group is unavailable.',
      onRetry: onRetry,
    );
  }
}

class _BalanceError extends StatelessWidget {
  const _BalanceError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _BalanceMessage(message: message, onRetry: onRetry);
  }
}

class _BalanceMessage extends StatelessWidget {
  const _BalanceMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
