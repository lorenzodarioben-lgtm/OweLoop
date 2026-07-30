import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../balances/state/balances_providers.dart';
import '../../groups/domain/group_models.dart';
import '../../groups/state/groups_providers.dart';
import '../../groups/state/groups_state.dart';
import '../domain/exact_money.dart';
import '../domain/expense_models.dart';
import '../state/expenses_providers.dart';
import '../validation/expense_validators.dart';
import 'expense_feedback.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  Set<String> _participantIds = <String>{};
  String? _payerMemberId;
  String? _participantsMessage;
  DateTime _occurredOn = DateTime.now();
  bool _hasInitializedMembers = false;
  bool _memberInitializationScheduled = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _initializeMembers(List<GroupMember> members) {
    if (_hasInitializedMembers || _memberInitializationScheduled) {
      return;
    }
    _memberInitializationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _participantIds = members.map((member) => member.id).toSet();
        _payerMemberId = members.isEmpty ? null : members.first.id;
        _hasInitializedMembers = true;
        _memberInitializationScheduled = false;
      });
    });
  }

  Future<void> _pickDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _occurredOn,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selectedDate != null && mounted) {
      setState(() => _occurredOn = selectedDate);
    }
  }

  EqualSplitPreview? _previewFor({
    required String currencyCode,
    required Set<String> participantIds,
  }) {
    final money = ExactMoney.tryParse(
      text: _amountController.text,
      currencyCode: currencyCode,
    );
    if (money == null || money.minorUnits <= 0 || participantIds.isEmpty) {
      return null;
    }
    return EqualSplitPreview.forParticipants(
      total: money,
      participantMemberIds: participantIds,
    );
  }

  Future<void> _submit({
    required AppGroup group,
    required Set<String> participantIds,
  }) async {
    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (participantIds.isEmpty) {
      setState(() => _participantsMessage = 'Select at least one participant.');
      return;
    }
    if (!isFormValid || _payerMemberId == null) {
      return;
    }

    final total = ExactMoney.tryParse(
      text: _amountController.text,
      currencyCode: group.currencyCode,
    );
    if (total == null || total.minorUnits <= 0) {
      return;
    }

    final expense = await ref
        .read(expenseCreationControllerProvider)
        .create(
          ExpenseCreationInput(
            groupId: group.id,
            description: _descriptionController.text,
            total: total,
            occurredAt: DateTime.utc(
              _occurredOn.year,
              _occurredOn.month,
              _occurredOn.day,
              12,
            ),
            payerMemberId: _payerMemberId!,
            participantMemberIds: participantIds.toList(),
          ),
        );

    if (expense != null && mounted) {
      await Future.wait([
        ref.read(expenseHistoryControllerProvider(group.id)).refresh(),
        ref
            .read(
              groupBalancesControllerProvider((
                groupId: group.id,
                currencyCode: group.currencyCode,
              )),
            )
            .refresh(),
      ]);
      if (mounted) {
        context.go(AppRoutes.expenseDetailPath(group.id, expense.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupState = ref
        .watch(groupDetailControllerProvider(widget.groupId))
        .state;
    final groupController = ref.read(
      groupDetailControllerProvider(widget.groupId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Add expense')),
      body: SafeArea(
        top: false,
        child: switch (groupState.status) {
          GroupDetailStatus.loading => const ExpenseLoadingView(
            label: 'Loading expense form',
          ),
          GroupDetailStatus.unavailable => ExpenseUnavailableView(
            title: 'This group is unavailable',
            message: 'It may no longer be available to you.',
            onRetry: groupController.load,
          ),
          GroupDetailStatus.error => ExpenseUnavailableView(
            title: 'We could not load this group',
            message:
                groupState.errorMessage ??
                'Check your connection and try again.',
            onRetry: groupController.load,
          ),
          GroupDetailStatus.ready => _ExpenseForm(
            group: groupState.group!,
            members: groupState.members,
            onMembersReady: _initializeMembers,
            formKey: _formKey,
            descriptionController: _descriptionController,
            amountController: _amountController,
            occurredOn: _occurredOn,
            payerMemberId: _payerMemberId,
            participantIds: _participantIds,
            participantsMessage: _participantsMessage,
            onPickDate: _pickDate,
            onPayerChanged: (value) => setState(() => _payerMemberId = value),
            onParticipantChanged: (memberId, selected) {
              setState(() {
                if (selected) {
                  _participantIds.add(memberId);
                } else {
                  _participantIds.remove(memberId);
                }
                _participantsMessage = null;
              });
            },
            onAmountChanged: (_) => setState(() {}),
            previewFor: _previewFor,
            onSubmit: _submit,
          ),
        },
      ),
    );
  }
}

class _ExpenseForm extends ConsumerWidget {
  const _ExpenseForm({
    required this.group,
    required this.members,
    required this.onMembersReady,
    required this.formKey,
    required this.descriptionController,
    required this.amountController,
    required this.occurredOn,
    required this.payerMemberId,
    required this.participantIds,
    required this.participantsMessage,
    required this.onPickDate,
    required this.onPayerChanged,
    required this.onParticipantChanged,
    required this.onAmountChanged,
    required this.previewFor,
    required this.onSubmit,
  });

  final AppGroup group;
  final List<GroupMember> members;
  final ValueChanged<List<GroupMember>> onMembersReady;
  final GlobalKey<FormState> formKey;
  final TextEditingController descriptionController;
  final TextEditingController amountController;
  final DateTime occurredOn;
  final String? payerMemberId;
  final Set<String> participantIds;
  final String? participantsMessage;
  final Future<void> Function() onPickDate;
  final ValueChanged<String?> onPayerChanged;
  final void Function(String memberId, bool selected) onParticipantChanged;
  final ValueChanged<String> onAmountChanged;
  final EqualSplitPreview? Function({
    required String currencyCode,
    required Set<String> participantIds,
  })
  previewFor;
  final Future<void> Function({
    required AppGroup group,
    required Set<String> participantIds,
  })
  onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    onMembersReady(members);
    final creationState = ref.watch(expenseCreationControllerProvider).state;
    final fractionDigits = CurrencyRules.fractionDigitsFor(group.currencyCode);
    if (fractionDigits == null) {
      return ExpenseUnavailableView(
        title: 'This currency is unavailable',
        message:
            'OweLoop cannot safely enter amounts for ${group.currencyCode} yet.',
        onRetry: () {},
      );
    }

    final preview = previewFor(
      currencyCode: group.currencyCode,
      participantIds: participantIds,
    );
    final membersById = <String, GroupMember>{
      for (final member in members) member.id: member,
    };
    final localizations = MaterialLocalizations.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Record a shared cost',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'The total is split equally in exact ${group.currencyCode} minor units.',
                ),
                const SizedBox(height: 24),
                if (creationState.errorMessage case final message?) ...[
                  ExpenseFeedbackMessage(message: message),
                  const SizedBox(height: 20),
                ],
                TextFormField(
                  controller: descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator: ExpenseValidators.description,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: fractionDigits > 0,
                  ),
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '${group.currencyCode} ',
                    hintText: fractionDigits == 0 ? '1000' : '10.00',
                  ),
                  onChanged: onAmountChanged,
                  validator: (value) =>
                      ExpenseValidators.amount(value, group.currencyCode),
                ),
                const SizedBox(height: 20),
                Text('Date', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: creationState.isSubmitting ? null : onPickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(localizations.formatMediumDate(occurredOn)),
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  key: ValueKey(payerMemberId),
                  initialValue: payerMemberId,
                  decoration: const InputDecoration(labelText: 'Payer'),
                  items: members
                      .map(
                        (member) => DropdownMenuItem(
                          value: member.id,
                          child: Text(
                            member.isGuest
                                ? '${member.displayName} (Guest)'
                                : member.displayName,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: creationState.isSubmitting ? null : onPayerChanged,
                  validator: (value) =>
                      value == null ? 'Choose a payer.' : null,
                ),
                const SizedBox(height: 24),
                Text(
                  'Participants',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                const Text('Choose who shares this cost.'),
                const SizedBox(height: 8),
                for (final member in members)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: participantIds.contains(member.id),
                    title: Text(member.displayName),
                    subtitle: member.isGuest ? const Text('Guest') : null,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: creationState.isSubmitting
                        ? null
                        : (selected) => onParticipantChanged(
                            member.id,
                            selected ?? false,
                          ),
                  ),
                if (participantsMessage case final message?) ...[
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Equal split preview',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (preview == null)
                  const Text('Enter a valid amount and select participants.'),
                if (preview != null) ...[
                  const Text(
                    'Any remainder is assigned in a stable member order so the split is reproducible.',
                  ),
                  const SizedBox(height: 8),
                  for (final share in preview.shares)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        membersById[share.memberId]?.displayName ?? 'Member',
                      ),
                      trailing: Text(share.amount.formatted),
                    ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: creationState.isSubmitting
                        ? null
                        : () => onSubmit(
                            group: group,
                            participantIds: participantIds,
                          ),
                    child: creationState.isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Post expense'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
