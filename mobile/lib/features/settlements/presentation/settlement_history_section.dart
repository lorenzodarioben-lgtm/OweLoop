import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';

import '../../balances/state/balances_providers.dart';
import '../domain/settlement_models.dart';
import '../state/settlements_providers.dart';
import '../state/settlements_state.dart';

class SettlementHistorySection extends ConsumerWidget {
  const SettlementHistorySection({
    required this.groupId,
    required this.currencyCode,
    super.key,
  });

  final String groupId;
  final String currencyCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = (groupId: groupId, currencyCode: currencyCode);
    final controller = ref.read(settlementHistoryControllerProvider(request));
    final state = ref.watch(settlementHistoryControllerProvider(request)).state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Settlements',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Refresh settlements',
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
        TextButton(
          onPressed: () => context.go(AppRoutes.settlementHistoryPath(groupId)),
          child: const Text('View all settlements'),
        ),
        switch (state.status) {
          SettlementHistoryStatus.loading => const _SettlementLoading(),
          SettlementHistoryStatus.unavailable => const _SettlementMessage(
            message: 'This group is unavailable.',
          ),
          SettlementHistoryStatus.error => _SettlementMessage(
            message:
                state.errorMessage ?? 'Check your connection and try again.',
            onRetry: controller.refresh,
          ),
          SettlementHistoryStatus.ready => _SettlementResults(
            state: state.copyWith(
              settlements: state.settlements.take(5).toList(),
            ),
            onVoid: (settlement) => _confirmVoid(
              context,
              settlement: settlement,
              onConfirm: () async {
                final wasVoided = await controller.voidSettlement(
                  settlement.id,
                );
                if (wasVoided) {
                  await ref
                      .read(
                        groupBalancesControllerProvider((
                          groupId: groupId,
                          currencyCode: currencyCode,
                        )),
                      )
                      .refresh();
                }
              },
            ),
          ),
        },
      ],
    );
  }

  Future<void> _confirmVoid(
    BuildContext context, {
    required SettlementRecord settlement,
    required Future<void> Function() onConfirm,
  }) async {
    final shouldVoid = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Void settlement?'),
        content: Text(
          '${settlement.statement} ${settlement.amount.formatted}. This keeps the record in history but removes its balance effect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Void settlement'),
          ),
        ],
      ),
    );
    if (shouldVoid == true) await onConfirm();
  }
}

class _SettlementResults extends StatelessWidget {
  const _SettlementResults({required this.state, required this.onVoid});

  final SettlementHistoryState state;
  final ValueChanged<SettlementRecord> onVoid;

  @override
  Widget build(BuildContext context) {
    if (state.settlements.isEmpty) {
      return const _SettlementMessage(
        message: 'No settlements have been recorded yet.',
      );
    }
    final localizations = MaterialLocalizations.of(context);
    return Column(
      children: [
        for (final settlement in state.settlements)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            leading: Icon(
              settlement.isVoided
                  ? Icons.cancel_outlined
                  : Icons.handshake_outlined,
            ),
            title: Text(settlement.statement),
            subtitle: Text(
              '${localizations.formatMediumDate(settlement.settledAt.toLocal())}${settlement.isVoided ? ' · Voided' : ''}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  settlement.amount.formatted,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (!settlement.isVoided)
                  IconButton(
                    tooltip: 'Void settlement',
                    onPressed: state.voidingSettlementId == null
                        ? () => onVoid(settlement)
                        : null,
                    icon: state.voidingSettlementId == settlement.id
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel_outlined),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SettlementLoading extends StatelessWidget {
  const _SettlementLoading();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Semantics(
      liveRegion: true,
      label: 'Loading settlements',
      child: Column(
        children: List.generate(
          2,
          (_) => Container(
            height: 64,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettlementMessage extends StatelessWidget {
  const _SettlementMessage({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        if (onRetry != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ],
    ),
  );
}
