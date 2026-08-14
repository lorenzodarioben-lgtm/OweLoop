import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../groups/domain/group_models.dart';
import '../domain/guest_claim_models.dart';
import '../state/guest_claims_providers.dart';
import '../validation/guest_claim_validators.dart';

class GuestClaimDialog extends ConsumerStatefulWidget {
  const GuestClaimDialog({
    required this.groupId,
    required this.guest,
    super.key,
  });

  final String groupId;
  final GroupMember guest;

  @override
  ConsumerState<GuestClaimDialog> createState() => _GuestClaimDialogState();
}

class _GuestClaimDialogState extends ConsumerState<GuestClaimDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final created = await ref
        .read(groupGuestClaimsControllerProvider(widget.groupId))
        .create(
          guestMemberId: widget.guest.id,
          input: GuestClaimInput(email: _emailController.text),
        );
    if (created && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref
        .watch(groupGuestClaimsControllerProvider(widget.groupId))
        .state;
    final isSubmitting = state.creatingGuestMemberId == widget.guest.id;
    return AlertDialog(
      title: Text('Claim ${widget.guest.displayName}?'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The person must accept this request in OweLoop. Their existing guest history, balance, and member ID will stay unchanged.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('guest-claim-email-input'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              enabled: !state.isBusy,
              decoration: const InputDecoration(labelText: 'Registered email'),
              validator: GuestClaimValidators.email,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (state.errorMessage case final message?) ...[
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: state.isBusy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('create-guest-claim-button'),
          onPressed: state.isBusy ? null : _submit,
          child: isSubmitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send claim request'),
        ),
      ],
    );
  }
}
