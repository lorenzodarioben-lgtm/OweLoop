import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/authentication_providers.dart';
import '../validation/auth_validators.dart';
import 'auth_screen_layout.dart';

class UpdatePasswordScreen extends ConsumerStatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  ConsumerState<UpdatePasswordScreen> createState() =>
      _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends ConsumerState<UpdatePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(authenticationControllerProvider)
        .updatePassword(password: _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authenticationControllerProvider).state;
    return AuthScreenLayout(
      title: 'Choose a new password',
      subtitle: 'Set a new password for your OweLoop account.',
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
              controller: _passwordController,
              autocorrect: false,
              autofillHints: const [AutofillHints.newPassword],
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'New password',
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: AuthValidators.password,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmationController,
              autocorrect: false,
              autofillHints: const [AutofillHints.newPassword],
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Confirm new password',
              ),
              validator: (value) => AuthValidators.passwordConfirmation(
                password: _passwordController.text,
                confirmation: value ?? '',
              ),
            ),
            const SizedBox(height: 24),
            AuthenticationSubmitButton(
              label: 'Update password',
              isLoading: state.isSubmitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
