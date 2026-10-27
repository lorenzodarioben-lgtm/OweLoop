import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/operations/history_page.dart';
import '../../groups/state/groups_providers.dart';
import '../domain/expense_models.dart';
import '../domain/expense_category.dart';
import '../state/expenses_providers.dart';
import '../state/expenses_state.dart';

class ExpenseHistoryScreen extends ConsumerStatefulWidget {
  const ExpenseHistoryScreen({required this.groupId, super.key});
  final String groupId;
  @override
  ConsumerState<ExpenseHistoryScreen> createState() =>
      _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends ConsumerState<ExpenseHistoryScreen> {
  final _query = TextEditingController();
  bool _includeVoided = true;
  DateTimeRange? _dates;
  String? _memberId;
  String? _categoryKey;
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _filter() => ref
      .read(allExpenseHistoryControllerProvider(widget.groupId))
      .filter(
        ExpenseHistoryFilter(
          query: _query.text,
          includeVoided: _includeVoided,
          from: _dates?.start,
          until: _dates?.end.add(const Duration(days: 1)),
          memberId: _memberId,
          categoryKey: _categoryKey,
        ),
      );
  @override
  Widget build(BuildContext context) {
    final controller = ref.read(
      allExpenseHistoryControllerProvider(widget.groupId),
    );
    final state = ref
        .watch(allExpenseHistoryControllerProvider(widget.groupId))
        .state;
    final members = ref
        .watch(groupDetailControllerProvider(widget.groupId))
        .state
        .members;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense history'),
        actions: [
          IconButton(
            tooltip: 'Refresh history',
            onPressed: state.isRefreshing ? null : controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _query,
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: 'Search expenses',
                    suffixIcon: IconButton(
                      tooltip: 'Search',
                      onPressed: _filter,
                      icon: const Icon(Icons.search),
                    ),
                  ),
                  onSubmitted: (_) => _filter(),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _memberId,
                  decoration: const InputDecoration(labelText: 'Participant'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All participants'),
                    ),
                    ...members.map(
                      (member) => DropdownMenuItem(
                        value: member.id,
                        child: Text(member.displayName),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _memberId = value);
                    _filter();
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: _categoryKey,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All categories'),
                    ),
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Uncategorized'),
                    ),
                    for (final value in ExpenseCategory.values)
                      DropdownMenuItem(
                        value: value.name,
                        child: Text(value.label),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() => _categoryKey = value);
                    _filter();
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Include voided'),
                        value: _includeVoided,
                        onChanged: (value) {
                          setState(() => _includeVoided = value ?? true);
                          _filter();
                        },
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final selected = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          initialDateRange: _dates,
                        );
                        if (selected != null && mounted) {
                          setState(() => _dates = selected);
                          await _filter();
                        }
                      },
                      child: Text(
                        _dates == null ? 'Date range' : 'Change dates',
                      ),
                    ),
                    if (_dates != null)
                      IconButton(
                        tooltip: 'Clear date filter',
                        onPressed: () {
                          setState(() => _dates = null);
                          _filter();
                        },
                        icon: const Icon(Icons.clear),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(state.errorMessage!),
            ),
          Expanded(
            child: state.status == ExpenseHistoryStatus.loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: controller.refresh,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: state.expenses.length + 1,
                      itemBuilder: (context, index) {
                        if (index == state.expenses.length) {
                          if (state.isRefreshing) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: state.hasMore
                                ? OutlinedButton(
                                    onPressed: controller.loadMore,
                                    child: const Text('Load older expenses'),
                                  )
                                : Text(
                                    state.expenses.isEmpty
                                        ? 'No expenses match these filters.'
                                        : 'End of history.',
                                  ),
                          );
                        }
                        final expense = state.expenses[index];
                        return ListTile(
                          title: Text(expense.description),
                          leading: Tooltip(
                            message: expense.categoryLabel,
                            child: const Icon(Icons.receipt_long_outlined),
                          ),
                          subtitle: Text(
                            '${MaterialLocalizations.of(context).formatMediumDate(expense.occurredAt.toLocal())}${expense.status == ExpenseStatus.voided ? ' · Voided' : ''}',
                          ),
                          trailing: Text(expense.total.formatted),
                          onTap: () => context.push(
                            AppRoutes.expenseDetailPath(
                              widget.groupId,
                              expense.id,
                            ),
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
