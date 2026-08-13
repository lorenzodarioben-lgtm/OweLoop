import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/expense_models.dart';
import '../state/expenses_providers.dart';
import '../state/expenses_state.dart';
import 'expense_feedback.dart';

class ExpenseDetailScreen extends ConsumerWidget {
  const ExpenseDetailScreen({
    required this.groupId,
    required this.expenseId,
    super.key,
  });

  final String groupId;
  final String expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = (groupId: groupId, expenseId: expenseId);
    final controller = ref.read(expenseDetailControllerProvider(request));
    final state = ref.watch(expenseDetailControllerProvider(request)).state;

    return Scaffold(
      appBar: AppBar(title: const Text('Expense details')),
      body: SafeArea(
        top: false,
        child: switch (state.status) {
          ExpenseDetailStatus.loading => const ExpenseLoadingView(
            label: 'Loading expense',
          ),
          ExpenseDetailStatus.unavailable => ExpenseUnavailableView(
            title: 'This expense is unavailable',
            message: 'It may no longer be available to you.',
            onRetry: controller.load,
          ),
          ExpenseDetailStatus.error => ExpenseUnavailableView(
            title: 'We could not load this expense',
            message:
                state.errorMessage ?? 'Check your connection and try again.',
            onRetry: controller.load,
          ),
          ExpenseDetailStatus.ready => _ExpenseDetailContent(
            expense: state.expense!,
          ),
        },
      ),
    );
  }
}

class _ExpenseDetailContent extends StatelessWidget {
  const _ExpenseDetailContent({required this.expense});

  final ExpenseRecord expense;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        Text(
          expense.description,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          expense.total.formatted,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text(expense.status.label)),
            Chip(label: Text(expense.total.currencyCode)),
          ],
        ),
        const SizedBox(height: 20),
        _DetailRow(
          label: 'Date',
          value: localizations.formatMediumDate(expense.occurredAt.toLocal()),
        ),
        const SizedBox(height: 24),
        Text('Payer', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (expense.payers.isEmpty)
          const Text('Payer details are unavailable.')
        else
          for (final payer in expense.payers)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text(
                '${payer.displayName} paid ${payer.amount.formatted}',
              ),
            ),
        const SizedBox(height: 24),
        Text(
          'What each person owes',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        for (final split in expense.splits)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text(split.displayName),
            trailing: Text(split.amount.formatted),
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }
}
