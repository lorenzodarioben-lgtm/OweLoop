import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';

class OweLoopApp extends StatelessWidget {
  const OweLoopApp({required this.router, super.key});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'OweLoop',
      theme: appTheme,
      routerConfig: router,
    );
  }
}
