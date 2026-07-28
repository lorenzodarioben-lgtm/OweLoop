import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/authentication_providers.dart';
import '../validation/auth_validators.dart';
import 'auth_screen_layout.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await ref
        .read(authenticationControllerProvider)
        .completeProfile(displayName: _displayNameController.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authenticationControllerProvider).state;

    return AuthScreenLayout(
      title: 'Choose your display name',
      subtitle: 'This is how you will appear in future shared expense groups.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.errorMessage case final message?) ...[
              AuthenticationMessage(message: message),
              const SizedBox(height: 20),
            ],
            TextFormField(
              controller: _displayNameController,
              autofillHints: const [AutofillHints.name],
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Display name',
                helperText: 'You can use up to 80 characters.',
              ),
              validator: AuthValidators.displayName,
            ),
            const SizedBox(height: 24),
            AuthenticationSubmitButton(
              label: 'Continue',
              isLoading: state.isSubmitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
