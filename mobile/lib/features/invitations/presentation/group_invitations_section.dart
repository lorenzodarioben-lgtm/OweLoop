import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/invitation_models.dart';
import '../state/invitations_providers.dart';
import '../state/invitations_state.dart';
import '../validation/invitation_validators.dart';

class GroupInvitationsSection extends ConsumerStatefulWidget {
  const GroupInvitationsSection({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<GroupInvitationsSection> createState() =>
      _GroupInvitationsSectionState();
}

class _GroupInvitationsSectionState
    extends ConsumerState<GroupInvitationsSection> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final created = await ref
        .read(groupInvitationsControllerProvider(widget.groupId))
        .create(GroupInvitationInput(email: _emailController.text));
    if (created && mounted) {
      _emailController.clear();
    }
  }

  Future<void> _revoke(String invitationId, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoke invitation?'),
        content: Text('This will remove the pending invitation for $email.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Revoke invitation'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref
          .read(groupInvitationsControllerProvider(widget.groupId))
          .revoke(invitationId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref
        .watch(groupInvitationsControllerProvider(widget.groupId))
        .state;
    final controller = ref.read(
      groupInvitationsControllerProvider(widget.groupId),
    );
    final localizations = MaterialLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Invite registered member',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter the email they use for OweLoop. Invitations are delivered to their in-app inbox and always join as a member.',
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('group-invitation-email-input'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                enabled:
                    !state.isCreating && state.revokingInvitationId == null,
                decoration: const InputDecoration(
                  labelText: 'Registered email',
                ),
                validator: InvitationValidators.email,
                onFieldSubmitted: (_) => _create(),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('create-group-invitation-button'),
                onPressed:
                    state.isCreating || state.revokingInvitationId != null
                    ? null
                    : _create,
                icon: state.isCreating
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Send invitation'),
              ),
            ],
          ),
        ),
        if (state.errorMessage case final message?) ...[
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (state.successMessage case final message?) ...[
          const SizedBox(height: 12),
          Text(message),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Text(
              'Pending invitations',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Refresh invitations',
              onPressed: state.isCreating || state.revokingInvitationId != null
                  ? null
                  : controller.load,
              icon: state.isRefreshing
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
        if (state.status == GroupInvitationsStatus.loading)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (state.invitations.isEmpty)
          const Text('There are no pending invitations for this group.')
        else
          for (final invitation in state.invitations)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(invitation.recipientEmail),
              subtitle: Text(
                'Expires ${localizations.formatMediumDate(invitation.expiresAt.toLocal())}',
              ),
              trailing: TextButton(
                onPressed:
                    state.revokingInvitationId != null || state.isCreating
                    ? null
                    : () => _revoke(invitation.id, invitation.recipientEmail),
                child: state.revokingInvitationId == invitation.id
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Revoke'),
              ),
            ),
      ],
    );
  }
}
