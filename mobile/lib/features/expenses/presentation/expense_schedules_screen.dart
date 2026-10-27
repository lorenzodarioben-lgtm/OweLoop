import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../authentication/state/authentication_providers.dart';
import '../data/expense_schedules_repository.dart';
import '../domain/expense_schedule.dart';

class ExpenseSchedulesScreen extends ConsumerStatefulWidget {
  const ExpenseSchedulesScreen({required this.groupId, super.key});
  final String groupId;
  @override
  ConsumerState<ExpenseSchedulesScreen> createState() =>
      _ExpenseSchedulesScreenState();
}

class _ExpenseSchedulesScreenState
    extends ConsumerState<ExpenseSchedulesScreen> {
  ExpenseSchedulePage? _page;
  bool _loading = true, _busy = false;
  String? _error;
  int _generation = 0;
  int _sessionGeneration = 0;
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  bool _current(int generation, String? account) =>
      mounted &&
      generation == _generation &&
      ref.read(authenticationControllerProvider).state.user?.id == account;
  Future<void> _load({bool more = false}) async {
    final account = ref.read(authenticationControllerProvider).state.user?.id;
    final generation = ++_generation;
    if (account == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final previous = _page;
      final result = await ref
          .read(expenseSchedulesRepositoryProvider)
          .load(
            widget.groupId,
            beforeDate: more ? previous?.nextDate : null,
            beforeId: more ? previous?.nextId : null,
          );
      if (!_current(generation, account)) return;
      setState(
        () => _page = ExpenseSchedulePage(
          result.schedules,
          [
            if (more && previous != null) ...previous.occurrences,
            ...result.occurrences,
          ],
          nextDate: result.nextDate,
          nextId: result.nextId,
        ),
      );
    } catch (_) {
      if (_current(generation, account)) {
        setState(
          () => _error =
              'Schedules could not refresh. Displayed data may be stale. Check your connection and retry.',
        );
      }
    } finally {
      if (_current(generation, account)) setState(() => _loading = false);
    }
  }

  Future<void> _act(
    Future<void> Function(ExpenseSchedulesRepository) action,
  ) async {
    if (_busy) return;
    final account = ref.read(authenticationControllerProvider).state.user?.id;
    final generation = _generation;
    final session = _sessionGeneration;
    setState(() => _busy = true);
    try {
      await action(ref.read(expenseSchedulesRepositoryProvider));
      if (_current(generation, account)) await _load();
    } catch (_) {
      if (_current(generation, account)) {
        setState(
          () => _error =
              'The schedule changed or could not be saved. Refresh before retrying. Calendar edits must start tomorrow or later. No expense is confirmed.',
        );
      }
    } finally {
      if (mounted &&
          session == _sessionGeneration &&
          ref.read(authenticationControllerProvider).state.user?.id ==
              account) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      authenticationControllerProvider.select((value) => value.state.user?.id),
      (previous, next) {
        if (previous != next) {
          _generation++;
          _sessionGeneration++;
          setState(() {
            _page = null;
            _error = null;
            _busy = false;
            _loading = true;
          });
          if (next != null) unawaited(_load());
        }
      },
    );
    final disabled = _loading || _busy || _error != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring drafts'),
        actions: [
          IconButton(
            tooltip: 'Refresh recurring drafts',
            onPressed: _loading || _busy ? null : () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Schedules only propose drafts. Review and explicitly post each expense. Nothing posts automatically. Create a schedule from Expense templates.',
            ),
            const Text(
              'Due discovery covers the last 90 days in each schedule’s timezone. Older ungenerated dates are omitted. Previously discovered history remains available.',
            ),
            if (_loading || _busy) const LinearProgressIndicator(),
            if (_error != null)
              Semantics(liveRegion: true, child: Text(_error!)),
            if (_error != null)
              TextButton(
                onPressed: _loading || _busy ? null : () => _load(),
                child: const Text('Retry'),
              ),
            if (_page != null && _page!.schedules.isEmpty)
              const Text('No recurring schedules yet.'),
            for (final schedule in _page?.schedules ?? <ExpenseSchedule>[])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${schedule.templateName} · ${schedule.cadence} · ${schedule.timezone}\n${schedule.cancelled
                          ? 'Cancelled'
                          : schedule.enabled
                          ? 'Enabled'
                          : 'Paused'} · Next: ${schedule.nextDate ?? 'none'}',
                    ),
                    if (schedule.canEdit)
                      Wrap(
                        children: [
                          TextButton(
                            onPressed: disabled
                                ? null
                                : () async {
                                    final account = ref
                                        .read(authenticationControllerProvider)
                                        .state
                                        .user
                                        ?.id;
                                    final config =
                                        await showScheduleConfiguration(
                                          context,
                                          schedule: schedule,
                                        );
                                    if (!mounted ||
                                        config == null ||
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
                                    await _act(
                                      (repo) => repo.update(schedule, config),
                                    );
                                  },
                            child: const Text('Edit / pause'),
                          ),
                          TextButton(
                            onPressed: disabled
                                ? null
                                : () async {
                                    final account = ref
                                        .read(authenticationControllerProvider)
                                        .state
                                        .user
                                        ?.id;
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (dialog) => AlertDialog(
                                        title: const Text(
                                          'Cancel this schedule?',
                                        ),
                                        content: const Text(
                                          'Due history stays readable. Unposted proposals become unavailable.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dialog, false),
                                            child: const Text('Keep schedule'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(dialog, true),
                                            child: const Text(
                                              'Cancel schedule',
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (!mounted ||
                                        confirmed != true ||
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
                                    await _act(
                                      (repo) => repo.update(schedule, {
                                        'p_name': schedule.name,
                                        'p_cadence': schedule.cadence,
                                        'p_anchor_date': schedule.anchorDate,
                                        'p_timezone': schedule.timezone,
                                        'p_enabled': false,
                                      }, cancel: true),
                                    );
                                  },
                            child: const Text('Cancel schedule'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            const Divider(),
            const Text('Due occurrences and history'),
            if (_page != null && _page!.occurrences.isEmpty)
              const Text('No discovered due occurrences.'),
            for (final occurrence
                in _page?.occurrences ?? <ExpenseOccurrence>[])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${occurrence.name} · ${occurrence.dueDate} · ${occurrence.state}',
                    ),
                    Text('Template snapshot: ${occurrence.template.name}'),
                    Wrap(
                      children: [
                        if (occurrence.canReview)
                          TextButton(
                            onPressed: disabled
                                ? null
                                : () async {
                                    await context.push(
                                      AppRoutes.newExpensePath(widget.groupId),
                                      extra: occurrence,
                                    );
                                    if (mounted) await _load();
                                  },
                            child: const Text('Review expense'),
                          ),
                        if (occurrence.canReview)
                          TextButton(
                            onPressed: disabled
                                ? null
                                : () async {
                                    final account = ref
                                        .read(authenticationControllerProvider)
                                        .state
                                        .user
                                        ?.id;
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (dialog) => AlertDialog(
                                        title: const Text(
                                          'Skip this occurrence?',
                                        ),
                                        content: const Text(
                                          'No expense will be recorded. This skip is retained in schedule history.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dialog, false),
                                            child: const Text('Back'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(dialog, true),
                                            child: const Text(
                                              'Skip occurrence',
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (mounted &&
                                        confirmed == true &&
                                        ref
                                                .read(
                                                  authenticationControllerProvider,
                                                )
                                                .state
                                                .user
                                                ?.id ==
                                            account) {
                                      await _act(
                                        (repo) => repo.skip(occurrence.id),
                                      );
                                    }
                                  },
                            child: const Text('Skip occurrence'),
                          ),
                        if (occurrence.expenseId != null)
                          TextButton(
                            onPressed: () => context.push(
                              AppRoutes.expenseDetailPath(
                                widget.groupId,
                                occurrence.expenseId!,
                              ),
                            ),
                            child: const Text('View confirmed expense'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            if (_page?.nextId != null)
              TextButton(
                onPressed: disabled ? null : () => _load(more: true),
                child: const Text('Load older occurrences'),
              ),
          ],
        ),
      ),
    );
  }
}

Future<Map<String, dynamic>?> showScheduleConfiguration(
  BuildContext context, {
  ExpenseSchedule? schedule,
}) async {
  final form = GlobalKey<FormState>();
  var name = schedule?.name ?? '';
  var date =
      schedule?.anchorDate ?? DateTime.now().toIso8601String().substring(0, 10);
  var timezone = schedule?.timezone ?? 'UTC';
  var cadence = schedule?.cadence ?? 'monthly';
  var enabled = schedule?.enabled ?? true;
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(
          schedule == null
              ? 'Create recurring drafts'
              : 'Edit recurring drafts',
        ),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Template configuration is pinned at creation. Monthly dates clamp to the last day of shorter months. Calendar edits start tomorrow or later.',
                ),
                TextFormField(
                  initialValue: name,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Schedule name'),
                  onChanged: (v) => name = v,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter a name.' : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: cadence,
                  decoration: const InputDecoration(labelText: 'Cadence'),
                  items: [
                    for (final value in [
                      'daily',
                      'weekly',
                      'fortnightly',
                      'monthly',
                    ])
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                  onChanged: (v) => cadence = v!,
                ),
                TextFormField(
                  initialValue: date,
                  decoration: const InputDecoration(
                    labelText: 'Anchor date (YYYY-MM-DD)',
                  ),
                  onChanged: (v) => date = v,
                  validator: calendarDateError,
                ),
                TextFormField(
                  initialValue: timezone,
                  decoration: const InputDecoration(
                    labelText: 'IANA timezone',
                    helperText: 'For example Australia/Sydney or UTC',
                  ),
                  onChanged: (v) => timezone = v,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter a timezone.'
                      : null,
                ),
                if (schedule != null)
                  SwitchListTile(
                    title: const Text('Enabled'),
                    value: enabled,
                    onChanged: (v) => setDialogState(() => enabled = v),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialog, {
                  'p_name': name.trim(),
                  'p_cadence': cadence,
                  'p_anchor_date': date.trim(),
                  'p_timezone': timezone.trim(),
                  if (schedule != null) 'p_enabled': enabled,
                });
              }
            },
            child: const Text('Save schedule'),
          ),
        ],
      ),
    ),
  );
}
