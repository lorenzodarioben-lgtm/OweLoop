import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../groups/state/groups_providers.dart';
import '../../balances/state/balances_providers.dart';
import '../state/settlements_providers.dart';
import '../state/settlements_state.dart';

class SettlementHistoryScreen extends ConsumerWidget {
  const SettlementHistoryScreen({required this.groupId, super.key});
  final String groupId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupDetailControllerProvider(groupId)).state.group;
    if (group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settlement history')),
        body: const Center(
          child: Text('Load the group before viewing settlements.'),
        ),
      );
    }
    final request = (groupId: groupId, currencyCode: group.currencyCode);
    final state = ref.watch(settlementHistoryControllerProvider(request)).state;
    final controller = ref.read(settlementHistoryControllerProvider(request));
    return Scaffold(
      appBar: AppBar(title: const Text('Settlement history')),
      body: state.status == SettlementHistoryStatus.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: controller.refresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: state.settlements.length + 1,
                itemBuilder: (context, index) {
                  if (index == state.settlements.length) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: state.isRefreshing
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                              children: [
                                if (state.errorMessage != null)
                                  Text(state.errorMessage!),
                                if (state.hasMore)
                                  OutlinedButton(
                                    onPressed: controller.loadMore,
                                    child: const Text('Load older settlements'),
                                  )
                                else
                                  Text(
                                    state.settlements.isEmpty
                                        ? 'No settlements recorded.'
                                        : 'End of history.',
                                  ),
                              ],
                            ),
                    );
                  }
                  final settlement = state.settlements[index];
                  return ListTile(
                    title: Text(settlement.statement),
                    subtitle: Text(
                      '${settlement.amount.formatted}\n${MaterialLocalizations.of(context).formatMediumDate(settlement.settledAt.toLocal())}${settlement.isVoided ? ' · Voided' : ''}',
                    ),
                    isThreeLine: true,
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Settlement details'),
                        content: SelectableText(
                          '${settlement.statement}\n${settlement.amount.formatted}\n${settlement.settledAt.toLocal()}\n${settlement.isVoided ? 'Voided' : 'Recorded external payment'}\nReference: ${settlement.id}',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                    trailing: settlement.isVoided || group.isArchived
                        ? null
                        : TextButton(
                            onPressed: state.voidingSettlementId != null
                                ? null
                                : () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Void settlement?'),
                                        content: const Text(
                                          'The original record stays in history; its balance effect is removed.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Void'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true &&
                                        await controller.voidSettlement(
                                          settlement.id,
                                        )) {
                                      await ref
                                          .read(
                                            groupBalancesControllerProvider(
                                              request,
                                            ),
                                          )
                                          .refresh();
                                    }
                                  },
                            child: const Text('Void'),
                          ),
                  );
                },
              ),
            ),
    );
  }
}
