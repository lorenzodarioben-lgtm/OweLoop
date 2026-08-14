import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/authentication_providers.dart';
import 'auth_screen_layout.dart';

class VerificationPendingScreen extends ConsumerWidget {
  const VerificationPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authenticationControllerProvider).state;
    final email = state.pendingEmail;

    return AuthScreenLayout(
      title: 'Verify your email',
      subtitle: email == null || email.isEmpty
          ? 'Check your inbox for a verification link, then return to sign in.'
          : 'We sent a verification link to $email. Open it, then return here '
                'to sign in.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              'Your account is waiting for email verification. OweLoop cannot '
              'sign you in until the address is confirmed.',
            ),
          ),
          if (state.errorMessage case final message?) ...[
            const SizedBox(height: 20),
            AuthenticationMessage(message: message),
          ],
          if (state.noticeMessage case final message?) ...[
            const SizedBox(height: 20),
            Semantics(liveRegion: true, child: Text(message)),
          ],
          const SizedBox(height: 24),
          AuthenticationSubmitButton(
            label: 'Resend verification email',
            isLoading: state.isSubmitting,
            onPressed: ref
                .read(authenticationControllerProvider)
                .resendVerification,
          ),
          const SizedBox(height: 12),
          AuthenticationSubmitButton(
            label: 'Back to sign in',
            isLoading: false,
            onPressed: ref
                .read(authenticationControllerProvider)
                .dismissVerificationMessage,
          ),
        ],
      ),
    );
  }
}
