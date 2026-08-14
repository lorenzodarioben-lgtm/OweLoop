import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_bootstrap.dart';
import 'core/config/app_environment.dart';
import 'core/errors/app_configuration_exception.dart';
import 'core/errors/development_error_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
    final environment = AppEnvironment.fromDotEnv();

    await Supabase.initialize(
      url: environment.supabaseUrl,
      publishableKey: environment.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );

    runApp(const ProviderScope(child: OweLoopBootstrap()));
  } on AppConfigurationException catch (error) {
    runApp(ProviderScope(child: DevelopmentErrorApp(message: error.message)));
  } catch (error) {
    runApp(
      ProviderScope(
        child: DevelopmentErrorApp(
          message:
              'Unable to initialise OweLoop. Copy .env.example to .env and '
              'provide the Supabase development values.\n\nDetails: $error',
        ),
      ),
    );
  }
}
