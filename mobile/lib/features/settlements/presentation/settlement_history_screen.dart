import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../groups/state/groups_providers.dart';
import '../../balances/state/balances_providers.dart';
import '../state/settlements_providers.dart';
import '../state/settlements_state.dart';
import '../../../core/operations/history_page.dart';
import '../../groups/domain/group_models.dart';
import '../../expenses/domain/exact_money.dart';

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
    final state = ref
        .watch(allSettlementHistoryControllerProvider(request))
        .state;
    final controller = ref.read(
      allSettlementHistoryControllerProvider(request),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Settlement history')),
      body: Column(
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: _SettlementFilters(
                members: ref
                    .watch(groupDetailControllerProvider(groupId))
                    .state
                    .members,
                currency: group.currencyCode,
                onApply: controller.filter,
              ),
            ),
          ),
          Expanded(
            child: state.status == SettlementHistoryStatus.loading
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
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : Column(
                                    children: [
                                      if (state.errorMessage != null)
                                        Text(state.errorMessage!),
                                      if (state.hasMore)
                                        OutlinedButton(
                                          onPressed: controller.loadMore,
                                          child: const Text(
                                            'Load older settlements',
                                          ),
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
                                              title: const Text(
                                                'Void settlement?',
                                              ),
                                              content: const Text(
                                                'The original record stays in history; its balance effect is removed.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                  child: const Text('Cancel'),
                                                ),
                                                FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
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
          ),
        ],
      ),
    );
  }
}

class _SettlementFilters extends StatefulWidget {
  const _SettlementFilters({
    required this.members,
    required this.currency,
    required this.onApply,
  });
  final List<GroupMember> members;
  final String currency;
  final Future<void> Function(SettlementHistoryFilter) onApply;
  @override
  State<_SettlementFilters> createState() => _SettlementFiltersState();
}

class _SettlementFiltersState extends State<_SettlementFilters> {
  final _minimum = TextEditingController(), _maximum = TextEditingController();
  String? _payer, _receiver, _error;
  String _state = 'all';
  bool _oldest = false;
  DateTimeRange? _dates;
  @override
  void dispose() {
    _minimum.dispose();
    _maximum.dispose();
    super.dispose();
  }

  void _apply() {
    final min = _minimum.text.trim().isEmpty
        ? null
        : ExactMoney.tryParse(
            text: _minimum.text,
            currencyCode: widget.currency,
          );
    final max = _maximum.text.trim().isEmpty
        ? null
        : ExactMoney.tryParse(
            text: _maximum.text,
            currencyCode: widget.currency,
          );
    if ((_minimum.text.trim().isNotEmpty && min == null) ||
        (_maximum.text.trim().isNotEmpty && max == null) ||
        (min != null && max != null && min.minorUnits > max.minorUnits)) {
      setState(
        () => _error =
            'Enter valid minimum and maximum amounts in increasing order.',
      );
      return;
    }
    setState(() => _error = null);
    widget.onApply(
      SettlementHistoryFilter(
        from: _dates?.start,
        until: _dates?.end.add(const Duration(days: 1)),
        payingMemberId: _payer,
        receivingMemberId: _receiver,
        minMinor: min?.minorUnits,
        maxMinor: max?.minorUnits,
        state: _state,
        oldestFirst: _oldest,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('Filter settlements'),
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final paying in [true, false])
              DropdownButtonFormField<String>(
                initialValue: paying ? _payer : _receiver,
                decoration: InputDecoration(
                  labelText: paying ? 'Paying member' : 'Receiving member',
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All members'),
                  ),
                  for (final member in widget.members)
                    DropdownMenuItem(
                      value: member.id,
                      child: Text(member.displayName),
                    ),
                ],
                onChanged: (value) => setState(() {
                  if (paying) {
                    _payer = value;
                  } else {
                    _receiver = value;
                  }
                }),
              ),
            DropdownButtonFormField<String>(
              initialValue: _state,
              decoration: const InputDecoration(labelText: 'Record status'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All records')),
                DropdownMenuItem(
                  value: 'active',
                  child: Text('Active records'),
                ),
                DropdownMenuItem(
                  value: 'voided',
                  child: Text('Voided records'),
                ),
              ],
              onChanged: (value) => setState(() => _state = value ?? 'all'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minimum,
                    decoration: InputDecoration(
                      labelText: 'Minimum ${widget.currency}',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maximum,
                    decoration: InputDecoration(
                      labelText: 'Maximum ${widget.currency}',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              title: const Text('Oldest first'),
              value: _oldest,
              onChanged: (value) => setState(() => _oldest = value),
            ),
            Wrap(
              children: [
                TextButton(
                  onPressed: () async {
                    final dates = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      initialDateRange: _dates,
                    );
                    if (mounted && dates != null) {
                      setState(() => _dates = dates);
                    }
                  },
                  child: Text(
                    _dates == null
                        ? 'Select date range'
                        : 'Date range selected',
                  ),
                ),
                if (_dates != null)
                  TextButton(
                    onPressed: () => setState(() => _dates = null),
                    child: const Text('Clear dates'),
                  ),
                FilledButton(
                  onPressed: _apply,
                  child: const Text('Apply filters'),
                ),
              ],
            ),
            if (_error != null) Text(_error!),
          ],
        ),
      ),
    ],
  );
}
