import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/group_models.dart';
import '../state/groups_providers.dart';
import '../validation/group_validators.dart';
import 'group_feedback.dart';

class AddGuestDialog extends ConsumerStatefulWidget {
  const AddGuestDialog({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<AddGuestDialog> createState() => _AddGuestDialogState();
}

class _AddGuestDialogState extends ConsumerState<AddGuestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final added = await ref
        .read(groupDetailControllerProvider(widget.groupId))
        .addGuest(GuestCreationInput(displayName: _nameController.text));
    if (added && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref
        .watch(groupDetailControllerProvider(widget.groupId))
        .state;

    return AlertDialog(
      title: const Text('Add a guest'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Guests do not need an OweLoop account yet.'),
              const SizedBox(height: 20),
              if (state.errorMessage case final message?) ...[
                GroupFeedbackMessage(message: message),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _nameController,
                autofocus: true,
                autofillHints: const [AutofillHints.name],
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Guest display name',
                ),
                validator: GroupValidators.guestName,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: state.isAddingGuest
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: state.isAddingGuest ? null : _submit,
          child: state.isAddingGuest
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add guest'),
        ),
      ],
    );
  }
}
