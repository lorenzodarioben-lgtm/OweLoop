import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/operations/client_operation_id.dart';
import '../../groups/domain/group_models.dart';
import '../../groups/state/group_data_refresh_coordinator.dart';
import '../../groups/state/groups_providers.dart';
import '../../groups/state/groups_state.dart';
import '../domain/exact_money.dart';
import '../domain/expense_models.dart';
import '../state/expenses_providers.dart';
import '../validation/expense_validators.dart';
import 'expense_feedback.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({required this.groupId, this.draft, super.key});

  final String groupId;
  final ExpenseRecord? draft;

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final Map<String, TextEditingController> _payerAmountControllers = {};
  final Map<String, TextEditingController> _splitValueControllers = {};
  Set<String> _participantIds = <String>{};
  Set<String> _payerIds = <String>{};
  String? _singlePayerMemberId;
  SplitMethod _splitMethod = SplitMethod.equal;
  DateTime _occurredOn = DateTime.now();
  bool _multiplePayers = false;
  bool _hasInitializedMembers = false;
  String? _payerMessage;
  String? _splitMessage;
  String? _operationId;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    if (draft != null) {
      _descriptionController.text = draft.description;
      _amountController.text = _inputAmount(draft.total);
      _occurredOn = draft.occurredAt.toLocal();
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    for (final controller in _payerAmountControllers.values) {
      controller.dispose();
    }
    for (final controller in _splitValueControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeMembers(List<GroupMember> members) {
    if (_hasInitializedMembers || members.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasInitializedMembers) return;
      setState(() {
        _participantIds = members.map((member) => member.id).toSet();
        _singlePayerMemberId = members.first.id;
        _payerIds = {members.first.id};
        for (final member in members) {
          _payerAmountControllers[member.id] = TextEditingController();
          _splitValueControllers[member.id] = TextEditingController(
            text: _splitMethod == SplitMethod.percentage
                ? _initialBasisPointInput(members.length)
                : '1',
          );
        }
        final draft = widget.draft;
        if (draft != null) {
          _participantIds = draft.splits.map((split) => split.memberId).toSet();
          _payerIds = draft.payers.map((payer) => payer.memberId).toSet();
          _multiplePayers = draft.payers.length > 1;
          _singlePayerMemberId = draft.payers.isEmpty
              ? _singlePayerMemberId
              : draft.payers.first.memberId;
          _splitMethod = SplitMethod.exact;
          for (final payer in draft.payers) {
            _payerAmountControllers[payer.memberId]?.text = _inputAmount(
              payer.amount,
            );
          }
          for (final split in draft.splits) {
            _splitValueControllers[split.memberId]?.text = _inputAmount(
              split.amount,
            );
          }
        }
        _hasInitializedMembers = true;
      });
    });
  }

  String _initialBasisPointInput(int memberCount) {
    final base = 10000 ~/ memberCount;
    return '${base ~/ 100}.${(base % 100).toString().padLeft(2, '0')}';
  }

  String _inputAmount(ExactMoney amount) {
    final fractionDigits = CurrencyRules.fractionDigitsFor(
      amount.currencyCode,
    )!;
    if (fractionDigits == 0) return '${amount.minorUnits}';
    final scale = fractionDigits == 2 ? 100 : 1;
    return '${amount.minorUnits ~/ scale}.${(amount.minorUnits % scale).toString().padLeft(fractionDigits, '0')}';
  }

  Future<void> _pickDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _occurredOn,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selectedDate != null && mounted) {
      setState(() {
        _occurredOn = selectedDate;
        _operationId = null;
      });
    }
  }

  void _setSplitMethod(SplitMethod? value, List<GroupMember> members) {
    if (value == null) return;
    setState(() {
      _splitMethod = value;
      _splitMessage = null;
      _operationId = null;
      if (value == SplitMethod.shares) {
        for (final member in members) {
          _splitValueControllers[member.id]?.text = '1';
        }
      }
      if (value == SplitMethod.percentage) {
        for (final member in members) {
          _splitValueControllers[member.id]?.text = _initialBasisPointInput(
            members.length,
          );
        }
      }
    });
  }

  List<ExpenseAllocation>? _previewFor({
    required String currencyCode,
    required Set<String> participantIds,
  }) {
    final total = ExactMoney.tryParse(
      text: _amountController.text,
      currencyCode: currencyCode,
    );
    if (total == null || total.minorUnits <= 0 || participantIds.isEmpty) {
      return null;
    }
    try {
      return _buildSplits(total: total, participantIds: participantIds);
    } on SplitAllocationException {
      return null;
    }
  }

  List<ExpenseAllocation> _buildSplits({
    required ExactMoney total,
    required Set<String> participantIds,
  }) {
    return switch (_splitMethod) {
      SplitMethod.equal => SplitAllocationCalculator.equal(
        totalMinor: total.minorUnits,
        memberIds: participantIds,
      ),
      SplitMethod.exact => SplitAllocationCalculator.exact(
        totalMinor: total.minorUnits,
        amountsByMemberId: {
          for (final memberId in participantIds)
            memberId: _minorInput(
              _splitValueControllers[memberId]?.text ?? '',
              total.currencyCode,
            ),
        },
      ),
      SplitMethod.percentage => SplitAllocationCalculator.percentages(
        totalMinor: total.minorUnits,
        basisPointsByMemberId: {
          for (final memberId in participantIds)
            memberId: _basisPoints(
              _splitValueControllers[memberId]?.text ?? '',
            ),
        },
      ),
      SplitMethod.shares => SplitAllocationCalculator.shares(
        totalMinor: total.minorUnits,
        sharesByMemberId: {
          for (final memberId in participantIds)
            memberId: _positiveInteger(
              _splitValueControllers[memberId]?.text ?? '',
            ),
        },
      ),
    };
  }

  int _minorInput(String value, String currencyCode) {
    final money = ExactMoney.tryParse(text: value, currencyCode: currencyCode);
    if (money == null) {
      throw const SplitAllocationException('Enter valid exact split amounts.');
    }
    return money.minorUnits;
  }

  int _basisPoints(String value) {
    final match = RegExp(
      r'^(\d{1,3})(?:\.(\d{1,2}))?$',
    ).firstMatch(value.trim());
    if (match == null) {
      throw const SplitAllocationException(
        'Enter percentages with up to two decimal places.',
      );
    }
    final whole = int.parse(match.group(1)!);
    final decimal = (match.group(2) ?? '').padRight(2, '0');
    final basisPoints =
        whole * 100 + int.parse(decimal.isEmpty ? '0' : decimal);
    if (basisPoints > 10000) {
      throw const SplitAllocationException(
        'A percentage cannot exceed 100.00%.',
      );
    }
    return basisPoints;
  }

  int _positiveInteger(String value) {
    final amount = int.tryParse(value.trim());
    if (amount == null || amount <= 0) {
      throw const SplitAllocationException(
        'Enter a positive whole-number share count.',
      );
    }
    return amount;
  }

  List<ExpenseAllocation> _buildPayers(ExactMoney total) {
    if (!_multiplePayers) {
      if (_singlePayerMemberId == null) {
        throw const SplitAllocationException('Choose who paid.');
      }
      return [
        ExpenseAllocation(
          memberId: _singlePayerMemberId!,
          amountMinor: total.minorUnits,
        ),
      ];
    }
    if (_payerIds.isEmpty) {
      throw const SplitAllocationException('Select at least one payer.');
    }
    final allocations = [
      for (final memberId in _payerIds)
        ExpenseAllocation(
          memberId: memberId,
          amountMinor: _minorInput(
            _payerAmountControllers[memberId]?.text ?? '',
            total.currencyCode,
          ),
        ),
    ];
    if (allocations.any((allocation) => allocation.amountMinor <= 0)) {
      throw const SplitAllocationException(
        'Each payer amount must be positive.',
      );
    }
    final paidTotal = MoneyMath.sum(
      allocations.map((allocation) => allocation.amountMinor),
    );
    if (paidTotal != BigInt.from(total.minorUnits)) {
      throw const SplitAllocationException(
        'Payer amounts must equal the expense total.',
      );
    }
    return allocations;
  }

  Future<void> _submit({
    required AppGroup group,
    required Set<String> participantIds,
  }) async {
    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (participantIds.isEmpty) {
      setState(() => _splitMessage = 'Select at least one participant.');
      return;
    }
    if (!isFormValid) return;
    final total = ExactMoney.tryParse(
      text: _amountController.text,
      currencyCode: group.currencyCode,
    );
    if (total == null || total.minorUnits <= 0) return;

    late final List<ExpenseAllocation> payers;
    late final List<ExpenseAllocation> splits;
    try {
      payers = _buildPayers(total);
      splits = _buildSplits(total: total, participantIds: participantIds);
    } on SplitAllocationException catch (error) {
      setState(() {
        _payerMessage = _multiplePayers ? error.message : null;
        _splitMessage = _multiplePayers ? null : error.message;
      });
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
            operationId: _operationId ??= ClientOperationId.generate().value,
            payers: payers,
            splits: splits,
            splitMethod: _splitMethod,
            payerMemberId: _singlePayerMemberId,
            participantMemberIds: participantIds.toList(),
          ),
        );
    if (expense != null && mounted) {
      await ref
          .read(
            groupDataRefreshCoordinatorProvider((
              groupId: group.id,
              currencyCode: group.currencyCode,
            )),
          )
          .refresh();
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
            formKey: _formKey,
            descriptionController: _descriptionController,
            amountController: _amountController,
            payerAmountControllers: _payerAmountControllers,
            splitValueControllers: _splitValueControllers,
            occurredOn: _occurredOn,
            singlePayerMemberId: _singlePayerMemberId,
            payerIds: _payerIds,
            participantIds: _participantIds,
            multiplePayers: _multiplePayers,
            splitMethod: _splitMethod,
            payerMessage: _payerMessage,
            splitMessage: _splitMessage,
            onMembersReady: _initializeMembers,
            onPickDate: _pickDate,
            onSinglePayerChanged: (value) => setState(() {
              _singlePayerMemberId = value;
              _operationId = null;
            }),
            onMultiplePayersChanged: (value) => setState(() {
              _multiplePayers = value;
              _payerMessage = null;
              _operationId = null;
              if (value && _singlePayerMemberId != null) {
                _payerIds = {_singlePayerMemberId!};
                _payerAmountControllers[_singlePayerMemberId!]?.text =
                    _amountController.text;
              }
            }),
            onPayerChanged: (memberId, selected) => setState(() {
              if (selected) {
                _payerIds.add(memberId);
                _payerAmountControllers[memberId]?.text =
                    _amountController.text;
              } else {
                _payerIds.remove(memberId);
              }
              _payerMessage = null;
              _operationId = null;
            }),
            onParticipantChanged: (memberId, selected) => setState(() {
              if (selected) {
                _participantIds.add(memberId);
              } else {
                _participantIds.remove(memberId);
              }
              _splitMessage = null;
              _operationId = null;
            }),
            onSplitMethodChanged: (value) =>
                _setSplitMethod(value, groupState.members),
            onAmountChanged: (_) => setState(() => _operationId = null),
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
    required this.formKey,
    required this.descriptionController,
    required this.amountController,
    required this.payerAmountControllers,
    required this.splitValueControllers,
    required this.occurredOn,
    required this.singlePayerMemberId,
    required this.payerIds,
    required this.participantIds,
    required this.multiplePayers,
    required this.splitMethod,
    required this.payerMessage,
    required this.splitMessage,
    required this.onMembersReady,
    required this.onPickDate,
    required this.onSinglePayerChanged,
    required this.onMultiplePayersChanged,
    required this.onPayerChanged,
    required this.onParticipantChanged,
    required this.onSplitMethodChanged,
    required this.onAmountChanged,
    required this.previewFor,
    required this.onSubmit,
  });

  final AppGroup group;
  final List<GroupMember> members;
  final GlobalKey<FormState> formKey;
  final TextEditingController descriptionController;
  final TextEditingController amountController;
  final Map<String, TextEditingController> payerAmountControllers;
  final Map<String, TextEditingController> splitValueControllers;
  final DateTime occurredOn;
  final String? singlePayerMemberId;
  final Set<String> payerIds;
  final Set<String> participantIds;
  final bool multiplePayers;
  final SplitMethod splitMethod;
  final String? payerMessage;
  final String? splitMessage;
  final ValueChanged<List<GroupMember>> onMembersReady;
  final Future<void> Function() onPickDate;
  final ValueChanged<String?> onSinglePayerChanged;
  final ValueChanged<bool> onMultiplePayersChanged;
  final void Function(String, bool) onPayerChanged;
  final void Function(String, bool) onParticipantChanged;
  final ValueChanged<SplitMethod?> onSplitMethodChanged;
  final ValueChanged<String> onAmountChanged;
  final List<ExpenseAllocation>? Function({
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
    final membersById = {for (final member in members) member.id: member};
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
                const Text(
                  'Choose who paid, how the cost is split, and review the exact result before posting.',
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
                  onChanged: onAmountChanged,
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
                Text(
                  'Who paid?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Multiple payers'),
                  subtitle: const Text(
                    'Split the amount paid between members.',
                  ),
                  value: multiplePayers,
                  onChanged: creationState.isSubmitting
                      ? null
                      : onMultiplePayersChanged,
                ),
                if (!multiplePayers)
                  DropdownButtonFormField<String>(
                    initialValue: singlePayerMemberId,
                    decoration: const InputDecoration(labelText: 'Payer'),
                    items: _memberItems(members),
                    onChanged: creationState.isSubmitting
                        ? null
                        : onSinglePayerChanged,
                    validator: (value) =>
                        value == null ? 'Choose a payer.' : null,
                  )
                else
                  for (final member in members)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: payerIds.contains(member.id),
                      title: Text(member.displayName),
                      subtitle: payerIds.contains(member.id)
                          ? TextFormField(
                              controller: payerAmountControllers[member.id],
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: fractionDigits > 0,
                              ),
                              decoration: InputDecoration(
                                labelText: '${member.displayName} paid',
                                prefixText: '${group.currencyCode} ',
                              ),
                              onChanged: onAmountChanged,
                            )
                          : (member.isGuest ? const Text('Guest') : null),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: creationState.isSubmitting
                          ? null
                          : (selected) =>
                                onPayerChanged(member.id, selected ?? false),
                    ),
                if (payerMessage case final message?) ...[
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
                  'How is it split?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<SplitMethod>(
                  initialValue: splitMethod,
                  decoration: const InputDecoration(labelText: 'Split method'),
                  items: [
                    for (final method in SplitMethod.values)
                      DropdownMenuItem(
                        value: method,
                        child: Text(method.label),
                      ),
                  ],
                  onChanged: creationState.isSubmitting
                      ? null
                      : onSplitMethodChanged,
                ),
                const SizedBox(height: 4),
                Text(splitMethod.helper),
                const SizedBox(height: 12),
                for (final member in members)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: participantIds.contains(member.id),
                    title: Text(member.displayName),
                    subtitle:
                        participantIds.contains(member.id) &&
                            splitMethod != SplitMethod.equal
                        ? _splitInput(
                            member: member,
                            controller: splitValueControllers[member.id]!,
                            method: splitMethod,
                            currencyCode: group.currencyCode,
                            fractionDigits: fractionDigits,
                            onChanged: onAmountChanged,
                          )
                        : (member.isGuest ? const Text('Guest') : null),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: creationState.isSubmitting
                        ? null
                        : (selected) => onParticipantChanged(
                            member.id,
                            selected ?? false,
                          ),
                  ),
                if (splitMessage case final message?) ...[
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
                  splitMethod == SplitMethod.equal
                      ? 'Equal split preview'
                      : 'Exact preview',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (preview == null)
                  const Text('Enter a valid amount and complete this split.')
                else ...[
                  const Text(
                    'This is the exact amount each participant will owe.',
                  ),
                  const SizedBox(height: 8),
                  for (final allocation in preview)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        membersById[allocation.memberId]?.displayName ??
                            'Member',
                      ),
                      trailing: Text(
                        ExactMoney(
                          currencyCode: group.currencyCode,
                          minorUnits: allocation.amountMinor,
                        ).formatted,
                      ),
                    ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: Semantics(
                    button: true,
                    label: 'Post expense with exact allocation',
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _memberItems(List<GroupMember> members) => [
    for (final member in members)
      DropdownMenuItem(
        value: member.id,
        child: Text(
          member.isGuest ? '${member.displayName} (Guest)' : member.displayName,
        ),
      ),
  ];

  Widget _splitInput({
    required GroupMember member,
    required TextEditingController controller,
    required SplitMethod method,
    required String currencyCode,
    required int fractionDigits,
    required ValueChanged<String> onChanged,
  }) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.numberWithOptions(
      decimal: method != SplitMethod.shares,
    ),
    decoration: InputDecoration(
      labelText: switch (method) {
        SplitMethod.exact => '${member.displayName} owes',
        SplitMethod.percentage => '${member.displayName} percentage',
        SplitMethod.shares => '${member.displayName} shares',
        SplitMethod.equal => '',
      },
      prefixText: method == SplitMethod.exact ? '$currencyCode ' : null,
      suffixText: method == SplitMethod.percentage ? '%' : null,
    ),
    onChanged: onChanged,
  );
}
