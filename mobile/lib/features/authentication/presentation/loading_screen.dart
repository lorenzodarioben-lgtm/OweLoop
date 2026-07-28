import 'package:flutter/material.dart';

class AuthenticationLoadingScreen extends StatelessWidget {
  const AuthenticationLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Semantics(
            liveRegion: true,
            label: 'Restoring your session',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Restoring your session…'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
