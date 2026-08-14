import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../balances/state/balances_providers.dart';
import '../../expenses/domain/exact_money.dart';
import '../../expenses/validation/expense_validators.dart';
import '../../groups/domain/group_models.dart';
import '../../groups/state/groups_providers.dart';
import '../../groups/state/groups_state.dart';
import '../domain/settlement_models.dart';
import '../state/settlements_providers.dart';

class RecordSettlementScreen extends ConsumerStatefulWidget {
  const RecordSettlementScreen({required this.groupId, this.draft, super.key});

  final String groupId;
  final SettlementDraft? draft;

  @override
  ConsumerState<RecordSettlementScreen> createState() =>
      _RecordSettlementScreenState();
}

class _RecordSettlementScreenState
    extends ConsumerState<RecordSettlementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String? _payingMemberId;
  String? _receivingMemberId;
  DateTime _settledOn = DateTime.now();
  bool _hasInitialized = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _initialize(List<GroupMember> members) {
    if (_hasInitialized || members.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasInitialized) return;
      final draft = widget.draft;
      setState(() {
        _payingMemberId = draft?.payingMemberId ?? members.first.id;
        _receivingMemberId =
            draft?.receivingMemberId ??
            (members.length > 1 ? members[1].id : null);
        if (draft != null) {
          _amountController.text = _inputAmount(draft.amount);
        }
        _hasInitialized = true;
      });
    });
  }

  String _inputAmount(ExactMoney amount) {
    final fractionDigits = CurrencyRules.fractionDigitsFor(
      amount.currencyCode,
    )!;
    if (fractionDigits == 0) return '${amount.minorUnits}';
    final scale = fractionDigits == 2 ? 100 : 1;
    final whole = amount.minorUnits ~/ scale;
    final fraction = (amount.minorUnits % scale).toString().padLeft(
      fractionDigits,
      '0',
    );
    return '$whole.$fraction';
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _settledOn,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null && mounted) setState(() => _settledOn = selected);
  }

  Future<void> _submit(AppGroup group) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_payingMemberId == null || _receivingMemberId == null) return;
    if (_payingMemberId == _receivingMemberId) {
      setState(() {});
      return;
    }
    final amount = ExactMoney.tryParse(
      text: _amountController.text,
      currencyCode: group.currencyCode,
    );
    if (amount == null || amount.minorUnits <= 0) return;
    final settlement = await ref
        .read(settlementCreationControllerProvider)
        .record(
          SettlementCreationInput(
            groupId: group.id,
            payingMemberId: _payingMemberId!,
            receivingMemberId: _receivingMemberId!,
            amount: amount,
            settledAt: DateTime.utc(
              _settledOn.year,
              _settledOn.month,
              _settledOn.day,
              12,
            ),
          ),
        );
    if (settlement == null || !mounted) return;
    await Future.wait([
      ref
          .read(
            settlementHistoryControllerProvider((
              groupId: group.id,
              currencyCode: group.currencyCode,
            )),
          )
          .refresh(),
      ref
          .read(
            groupBalancesControllerProvider((
              groupId: group.id,
              currencyCode: group.currencyCode,
            )),
          )
          .refresh(),
    ]);
    if (mounted) context.go(AppRoutes.groupDetailPath(group.id));
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
      appBar: AppBar(title: const Text('Record settlement')),
      body: SafeArea(
        top: false,
        child: switch (groupState.status) {
          GroupDetailStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          GroupDetailStatus.unavailable => _Unavailable(
            message: 'This group is unavailable.',
            onRetry: groupController.load,
          ),
          GroupDetailStatus.error => _Unavailable(
            message:
                groupState.errorMessage ??
                'Check your connection and try again.',
            onRetry: groupController.load,
          ),
          GroupDetailStatus.ready => _SettlementForm(
            group: groupState.group!,
            members: groupState.members,
            formKey: _formKey,
            amountController: _amountController,
            payingMemberId: _payingMemberId,
            receivingMemberId: _receivingMemberId,
            settledOn: _settledOn,
            onReady: _initialize,
            onPayingChanged: (value) => setState(() => _payingMemberId = value),
            onReceivingChanged: (value) =>
                setState(() => _receivingMemberId = value),
            onPickDate: _pickDate,
            onSubmit: _submit,
          ),
        },
      ),
    );
  }
}

class _SettlementForm extends ConsumerWidget {
  const _SettlementForm({
    required this.group,
    required this.members,
    required this.formKey,
    required this.amountController,
    required this.payingMemberId,
    required this.receivingMemberId,
    required this.settledOn,
    required this.onReady,
    required this.onPayingChanged,
    required this.onReceivingChanged,
    required this.onPickDate,
    required this.onSubmit,
  });

  final AppGroup group;
  final List<GroupMember> members;
  final GlobalKey<FormState> formKey;
  final TextEditingController amountController;
  final String? payingMemberId;
  final String? receivingMemberId;
  final DateTime settledOn;
  final ValueChanged<List<GroupMember>> onReady;
  final ValueChanged<String?> onPayingChanged;
  final ValueChanged<String?> onReceivingChanged;
  final Future<void> Function() onPickDate;
  final Future<void> Function(AppGroup group) onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    onReady(members);
    final state = ref.watch(settlementCreationControllerProvider).state;
    final fractionDigits = CurrencyRules.fractionDigitsFor(group.currencyCode);
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
                  'Record a repayment',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Record a payment that has already happened. It never moves money automatically.',
                ),
                const SizedBox(height: 24),
                if (state.errorMessage case final message?) ...[
                  Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                DropdownButtonFormField<String>(
                  initialValue: payingMemberId,
                  decoration: const InputDecoration(labelText: 'Paid by'),
                  items: _items(members),
                  onChanged: state.isSubmitting ? null : onPayingChanged,
                  validator: (value) =>
                      value == null ? 'Choose who paid.' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: receivingMemberId,
                  decoration: const InputDecoration(labelText: 'Received by'),
                  items: _items(members),
                  onChanged: state.isSubmitting ? null : onReceivingChanged,
                  validator: (value) {
                    if (value == null) {
                      return 'Choose who received it.';
                    }
                    if (value == payingMemberId) {
                      return 'Choose two different members.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('settlement-amount-input'),
                  controller: amountController,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: fractionDigits != null && fractionDigits > 0,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '${group.currencyCode} ',
                  ),
                  validator: (value) =>
                      ExpenseValidators.amount(value, group.currencyCode),
                ),
                const SizedBox(height: 20),
                Text('Date', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: state.isSubmitting ? null : onPickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(localizations.formatMediumDate(settledOn)),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: state.isSubmitting
                        ? null
                        : () => onSubmit(group),
                    child: state.isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Record settlement'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _items(List<GroupMember> members) => members
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
      .toList();
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}
