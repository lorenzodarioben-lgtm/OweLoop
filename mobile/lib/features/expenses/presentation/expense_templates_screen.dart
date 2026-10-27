import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../groups/state/groups_providers.dart';
import '../data/expense_templates_repository.dart';
import '../data/expense_schedules_repository.dart';
import '../../authentication/state/authentication_providers.dart';
import 'expense_schedules_screen.dart';

class ExpenseTemplatesScreen extends ConsumerWidget {
  const ExpenseTemplatesScreen({required this.groupId, super.key});
  final String groupId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupDetailControllerProvider(groupId)).state.group;
    final templates = ref.watch(expenseTemplatesProvider(groupId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense templates'),
        actions: [
          IconButton(
            tooltip: 'Refresh templates',
            onPressed: () => ref.invalidate(expenseTemplatesProvider(groupId)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: templates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(templateErrorMessage(error)),
              TextButton(
                onPressed: () =>
                    ref.invalidate(expenseTemplatesProvider(groupId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (items) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Templates never affect balances. Use a template to open a new expense for review. Save or update configurations from the Add expense form. Inactive participants must be selected again.',
            ),
            if (group != null && !group.isArchived)
              TextButton(
                onPressed: () =>
                    context.push(AppRoutes.newExpensePath(groupId)),
                child: const Text('Create an expense template'),
              ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text('No group templates yet.'),
              ),
            for (final template in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(template.fields['description'] as String? ?? ''),
                    if (group != null && !group.isArchived)
                      Wrap(
                        children: [
                          TextButton(
                            onPressed: () async {
                              final account = ref
                                  .read(authenticationControllerProvider)
                                  .state
                                  .user
                                  ?.id;
                              final config = await showScheduleConfiguration(
                                context,
                              );
                              if (config == null ||
                                  !context.mounted ||
                                  ref
                                          .read(
                                            authenticationControllerProvider,
                                          )
                                          .state
                                          .user
                                          ?.id !=
                                      account) {
                                return;
                              }
                              try {
                                await ref
                                    .read(expenseSchedulesRepositoryProvider)
                                    .create(template.id, config);
                                if (context.mounted) {
                                  context.push(
                                    AppRoutes.expenseSchedulesPath(groupId),
                                  );
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Schedule could not be saved. Check name, date, timezone and current permissions, then retry.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Text('Create schedule'),
                          ),
                          TextButton(
                            onPressed: () => context.push(
                              AppRoutes.newExpensePath(groupId),
                              extra: template,
                            ),
                            child: const Text('Review / use'),
                          ),
                          if (template.canEdit)
                            TextButton(
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Delete template?'),
                                    content: const Text(
                                      'Only this saved configuration is deleted. Financial history is unchanged.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true) return;
                                try {
                                  await ref
                                      .read(expenseTemplatesRepositoryProvider)
                                      .delete(template);
                                  ref.invalidate(
                                    expenseTemplatesProvider(groupId),
                                  );
                                } catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          templateErrorMessage(error),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: const Text('Delete'),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
