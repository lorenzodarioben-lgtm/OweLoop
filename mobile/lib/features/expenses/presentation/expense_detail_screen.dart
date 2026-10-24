import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../activity/presentation/expense_activity_section.dart';
import '../../balances/state/balances_providers.dart';
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
            isVoiding: state.isVoiding,
            errorMessage: state.errorMessage,
            onVoid: () async {
              final wasVoided = await controller.voidExpense();
              if (wasVoided) {
                await Future.wait([
                  ref.read(expenseHistoryControllerProvider(groupId)).refresh(),
                  ref
                      .read(
                        groupBalancesControllerProvider((
                          groupId: groupId,
                          currencyCode: state.expense!.total.currencyCode,
                        )),
                      )
                      .refresh(),
                ]);
              }
            },
          ),
        },
      ),
    );
  }
}

class _ExpenseDetailContent extends StatelessWidget {
  const _ExpenseDetailContent({
    required this.expense,
    required this.isVoiding,
    required this.errorMessage,
    required this.onVoid,
  });

  final ExpenseRecord expense;
  final bool isVoiding;
  final String? errorMessage;
  final Future<void> Function() onVoid;

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
            Chip(label: Text(expense.categoryLabel)),
          ],
        ),
        if (errorMessage case final message?) ...[
          const SizedBox(height: 16),
          ExpenseFeedbackMessage(message: message),
        ],
        if (expense.status == ExpenseStatus.posted) ...[
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.tonalIcon(
                onPressed: isVoiding
                    ? null
                    : () => _confirmVoid(context, onVoid: onVoid),
                icon: isVoiding
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cancel_outlined),
                label: const Text('Void expense'),
              ),
              OutlinedButton.icon(
                onPressed: isVoiding
                    ? null
                    : () => context.go(
                        AppRoutes.newExpensePath(expense.groupId),
                        extra: expense,
                      ),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Void and duplicate'),
              ),
            ],
          ),
        ],
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
        const SizedBox(height: 24),
        ExpenseActivitySection(
          expenseId: expense.id,
          currencyCode: expense.total.currencyCode,
        ),
      ],
    );
  }

  Future<void> _confirmVoid(
    BuildContext context, {
    required Future<void> Function() onVoid,
  }) async {
    final shouldVoid = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Void this expense?'),
        content: const Text(
          'The expense will remain in the group history, but it will no longer affect balances.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Void expense'),
          ),
        ],
      ),
    );
    if (shouldVoid == true) await onVoid();
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
