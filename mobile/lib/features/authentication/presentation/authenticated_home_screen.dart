import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/authentication_providers.dart';
import 'auth_screen_layout.dart';

class AuthenticatedHomeScreen extends ConsumerWidget {
  const AuthenticatedHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authenticationControllerProvider).state;
    final profile = state.profile;
    final user = state.user;
    final displayName = profile?.displayName ?? 'there';

    return Scaffold(
      appBar: AppBar(
        title: const Text('OweLoop'),
        actions: [
          TextButton(
            onPressed: state.isSubmitting
                ? null
                : ref.read(authenticationControllerProvider).signOut,
            child: state.isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, $displayName',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (user?.email case final email? when email.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(email, style: Theme.of(context).textTheme.bodyLarge),
                  ],
                  const SizedBox(height: 32),
                  const Text(
                    'Groups and shared expenses will be added here soon. For '
                    'now, your OweLoop profile is ready.',
                  ),
                  if (state.errorMessage case final message?) ...[
                    const SizedBox(height: 24),
                    AuthenticationMessage(message: message),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
