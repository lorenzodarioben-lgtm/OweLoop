import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/expense_activity_controller.dart';
import '../state/expense_activity_providers.dart';

class ExpenseActivitySection extends ConsumerWidget {
  const ExpenseActivitySection({
    required this.expenseId,
    required this.currencyCode,
    super.key,
  });

  final String expenseId;
  final String currencyCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = (expenseId: expenseId, currencyCode: currencyCode);
    final controller = ref.read(expenseActivityControllerProvider(request));
    final state = ref.watch(expenseActivityControllerProvider(request)).state;
    final localizations = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Activity', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        switch (state.status) {
          ExpenseActivityStatus.loading => const LinearProgressIndicator(),
          ExpenseActivityStatus.unavailable => const Text(
            'Activity is unavailable.',
          ),
          ExpenseActivityStatus.error => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(state.errorMessage ?? 'Activity could not be loaded.'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: controller.load,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
          ExpenseActivityStatus.ready =>
            state.events.isEmpty
                ? const Text('No activity has been recorded yet.')
                : Column(
                    children: [
                      for (final event in state.events)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.history_outlined),
                          title: Text(event.title),
                          subtitle: Text(
                            [
                              ...?(event.detail == null
                                  ? null
                                  : [event.detail!]),
                              localizations.formatMediumDate(
                                event.occurredAt.toLocal(),
                              ),
                              localizations.formatTimeOfDay(
                                TimeOfDay.fromDateTime(
                                  event.occurredAt.toLocal(),
                                ),
                              ),
                            ].join(' · '),
                          ),
                        ),
                    ],
                  ),
        },
      ],
    );
  }
}
