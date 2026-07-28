import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../domain/group_models.dart';
import '../state/groups_providers.dart';
import '../validation/group_validators.dart';
import 'group_feedback.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _currencyCode;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final group = await ref
        .read(groupsControllerProvider)
        .createGroup(
          GroupCreationInput(
            name: _nameController.text,
            currencyCode: _currencyCode!,
          ),
        );
    if (group != null && mounted) {
      context.go(AppRoutes.groupDetailPath(group.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupsControllerProvider).state;

    return Scaffold(
      appBar: AppBar(title: const Text('Create group')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start a shared record',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose the people and spending details later. First, give this group a clear name and currency.',
                    ),
                    const SizedBox(height: 28),
                    if (state.errorMessage case final message?) ...[
                      GroupFeedbackMessage(message: message),
                      const SizedBox(height: 20),
                    ],
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Group name',
                      ),
                      validator: GroupValidators.groupName,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _currencyCode,
                      decoration: const InputDecoration(labelText: 'Currency'),
                      items: GroupValidators.supportedCurrencies
                          .map(
                            (currency) => DropdownMenuItem(
                              value: currency,
                              child: Text(currency),
                            ),
                          )
                          .toList(),
                      onChanged: state.isCreating
                          ? null
                          : (value) => setState(() => _currencyCode = value),
                      validator: GroupValidators.currency,
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: state.isCreating ? null : _submit,
                        child: state.isCreating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Create group'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
