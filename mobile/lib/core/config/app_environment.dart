import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../errors/app_configuration_exception.dart';

class AppEnvironment {
  const AppEnvironment({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;

  factory AppEnvironment.fromDotEnv() {
    final supabaseUrl = dotenv.env['SUPABASE_URL']?.trim() ?? '';
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
    final missingVariables = <String>[
      if (supabaseUrl.isEmpty) 'SUPABASE_URL',
      if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
    ];

    if (missingVariables.isNotEmpty) {
      throw AppConfigurationException(
        'Missing ${missingVariables.join(', ')}. Copy .env.example to .env '
        'and supply the Supabase development values.',
      );
    }

    return AppEnvironment(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
    );
  }
}
