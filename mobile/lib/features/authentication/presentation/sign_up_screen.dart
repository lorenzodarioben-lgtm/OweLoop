import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/authentication_providers.dart';
import '../validation/auth_validators.dart';
import 'auth_screen_layout.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await ref
        .read(authenticationControllerProvider)
        .signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authenticationControllerProvider).state;

    return AuthScreenLayout(
      title: 'Create your account',
      subtitle: 'Use an email address you can verify to get started.',
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
              controller: _emailController,
              autocorrect: false,
              autofillHints: const [AutofillHints.newUsername],
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Email address'),
              validator: AuthValidators.email,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              autocorrect: false,
              autofillHints: const [AutofillHints.newPassword],
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: 'Use at least 8 characters.',
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
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
              controller: _passwordConfirmationController,
              autocorrect: false,
              autofillHints: const [AutofillHints.newPassword],
              obscureText: _obscureConfirmation,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Confirm password',
                suffixIcon: IconButton(
                  tooltip: _obscureConfirmation
                      ? 'Show password'
                      : 'Hide password',
                  onPressed: () {
                    setState(() {
                      _obscureConfirmation = !_obscureConfirmation;
                    });
                  },
                  icon: Icon(
                    _obscureConfirmation
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) => AuthValidators.passwordConfirmation(
                password: _passwordController.text,
                confirmation: value ?? '',
              ),
            ),
            const SizedBox(height: 24),
            AuthenticationSubmitButton(
              label: 'Create account',
              isLoading: state.isSubmitting,
              onPressed: _submit,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: state.isSubmitting
                    ? null
                    : () => context.go('/sign-in'),
                child: const Text('I already have an account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
