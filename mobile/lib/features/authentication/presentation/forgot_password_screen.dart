import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../state/authentication_providers.dart';
import '../validation/auth_validators.dart';
import 'auth_screen_layout.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(authenticationControllerProvider)
        .requestPasswordRecovery(email: _emailController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authenticationControllerProvider).state;
    return AuthScreenLayout(
      title: 'Reset your password',
      subtitle:
          'Enter your email address and we will send instructions if an account uses it.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.errorMessage case final message?) ...[
              AuthenticationMessage(message: message),
              const SizedBox(height: 20),
            ],
            if (state.hasRequestedPasswordRecovery &&
                state.noticeMessage != null) ...[
              Semantics(liveRegion: true, child: Text(state.noticeMessage!)),
              const SizedBox(height: 20),
            ],
            TextFormField(
              controller: _emailController,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: 'Email address'),
              validator: AuthValidators.email,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            AuthenticationSubmitButton(
              label: 'Send reset instructions',
              isLoading: state.isSubmitting,
              onPressed: _submit,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: state.isSubmitting
                    ? null
                    : () => context.go(AppRoutes.signIn),
                child: const Text('Back to sign in'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
