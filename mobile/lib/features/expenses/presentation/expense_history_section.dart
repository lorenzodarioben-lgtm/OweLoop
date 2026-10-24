import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../domain/expense_models.dart';
import '../state/expenses_providers.dart';
import '../state/expenses_state.dart';
import 'expense_feedback.dart';

class ExpenseHistorySection extends ConsumerWidget {
  const ExpenseHistorySection({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(expenseHistoryControllerProvider(groupId));
    final state = ref.watch(expenseHistoryControllerProvider(groupId)).state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Expense history',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Refresh expenses',
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
          onPressed: () => context.go(AppRoutes.expenseHistoryPath(groupId)),
          child: const Text('View all expenses'),
        ),
        switch (state.status) {
          ExpenseHistoryStatus.loading => const _ExpenseHistoryLoading(),
          ExpenseHistoryStatus.error => _ExpenseHistoryError(
            message:
                state.errorMessage ?? 'Check your connection and try again.',
            onRetry: controller.refresh,
          ),
          ExpenseHistoryStatus.ready =>
            state.expenses.isEmpty
                ? _ExpenseHistoryEmpty(groupId: groupId)
                : _ExpenseHistoryList(
                    groupId: groupId,
                    expenses: state.expenses.take(5).toList(),
                  ),
        },
      ],
    );
  }
}

class _ExpenseHistoryLoading extends StatelessWidget {
  const _ExpenseHistoryLoading();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      label: 'Loading expenses',
      child: Column(
        children: List.generate(
          2,
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

class _ExpenseHistoryError extends StatelessWidget {
  const _ExpenseHistoryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExpenseFeedbackMessage(message: message),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    );
  }
}

class _ExpenseHistoryEmpty extends StatelessWidget {
  const _ExpenseHistoryEmpty({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('No posted expenses yet.'),
        const SizedBox(height: 8),
        const Text('Add the first cost to keep the group record clear.'),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => context.go(AppRoutes.newExpensePath(groupId)),
          icon: const Icon(Icons.add),
          label: const Text('Add expense'),
        ),
      ],
    );
  }
}

class _ExpenseHistoryList extends StatelessWidget {
  const _ExpenseHistoryList({required this.groupId, required this.expenses});

  final String groupId;
  final List<ExpenseRecord> expenses;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return Column(
      children: [
        for (final expense in expenses)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text(expense.description),
            subtitle: Text(
              '${localizations.formatMediumDate(expense.occurredAt.toLocal())}${expense.status == ExpenseStatus.voided ? ' · Voided' : ''}',
            ),
            trailing: Text(
              expense.total.formatted,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            onTap: () =>
                context.go(AppRoutes.expenseDetailPath(groupId, expense.id)),
          ),
      ],
    );
  }
}
