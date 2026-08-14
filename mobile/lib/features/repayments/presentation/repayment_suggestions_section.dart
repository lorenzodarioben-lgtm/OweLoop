import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../balances/domain/balance_models.dart';
import '../../balances/state/balances_providers.dart';
import '../../balances/state/balances_state.dart';
import '../../groups/domain/group_models.dart';
import '../../settlements/domain/settlement_models.dart';
import '../domain/repayment_suggestion_models.dart';

class RepaymentSuggestionsSection extends ConsumerWidget {
  const RepaymentSuggestionsSection({required this.group, super.key});

  final AppGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = (groupId: group.id, currencyCode: group.currencyCode);
    final state = ref.watch(groupBalancesControllerProvider(request)).state;
    if (state.status != GroupBalancesStatus.ready) {
      return const SizedBox.shrink();
    }

    final suggestions = switch (state.balances) {
      final balances => _suggestionsFor(balances),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Repayment suggestions',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Suggestions use current net balances. They never move money automatically.',
        ),
        const SizedBox(height: 12),
        if (suggestions == null)
          const Text('Suggestions are unavailable until balances reconcile.')
        else if (suggestions.isEmpty)
          const Text('No repayments are suggested. Everyone is settled up.')
        else
          for (final suggestion in suggestions)
            _SuggestionListItem(
              suggestion: suggestion,
              canRecord: !group.isArchived && !suggestion.involvesRemovedMember,
              onRecord: () => context.go(
                AppRoutes.newSettlementPath(group.id),
                extra: SettlementDraft(
                  payingMemberId: suggestion.payingMember.groupMemberId,
                  receivingMemberId: suggestion.receivingMember.groupMemberId,
                  amount: suggestion.amount,
                ),
              ),
            ),
      ],
    );
  }

  List<RepaymentSuggestion>? _suggestionsFor(List<GroupBalance> balances) {
    try {
      return DebtSimplifier.suggest(balances);
    } on FormatException {
      return null;
    }
  }
}

class _SuggestionListItem extends StatelessWidget {
  const _SuggestionListItem({
    required this.suggestion,
    required this.canRecord,
    required this.onRecord,
  });

  final RepaymentSuggestion suggestion;
  final bool canRecord;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final reason = suggestion.involvesRemovedMember
        ? 'Historical member: record manually outside this group.'
        : 'The group is archived.';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: const Icon(Icons.swap_horiz_outlined),
      title: Text(suggestion.statement),
      subtitle: Text(
        canRecord
            ? suggestion.amount.formatted
            : '${suggestion.amount.formatted} · $reason',
      ),
      trailing: OutlinedButton(
        onPressed: canRecord ? onRecord : null,
        child: const Text('Record'),
      ),
    );
  }
}
