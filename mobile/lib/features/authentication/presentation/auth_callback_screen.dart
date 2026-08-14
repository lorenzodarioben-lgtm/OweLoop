import 'package:flutter/material.dart';

import 'auth_screen_layout.dart';

class AuthCallbackScreen extends StatelessWidget {
  const AuthCallbackScreen({super.key});

  @override
  Widget build(BuildContext context) => AuthScreenLayout(
    title: 'Finishing your secure link',
    subtitle:
        'OweLoop is confirming this link. Keep the app open for a moment.',
    child: Semantics(
      liveRegion: true,
      label: 'Finishing your secure link',
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}
