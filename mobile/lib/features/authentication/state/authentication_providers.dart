import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';
import '../data/profile_repository.dart';
import '../data/supabase_auth_repository.dart';
import '../data/supabase_profile_repository.dart';
import 'authentication_controller.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(Supabase.instance.client);
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return SupabaseProfileRepository(Supabase.instance.client);
});

final authenticationControllerProvider =
    ChangeNotifierProvider<AuthenticationController>((ref) {
      final controller = AuthenticationController(
        authRepository: ref.watch(authRepositoryProvider),
        profileRepository: ref.watch(profileRepositoryProvider),
      );
      controller.initialize();
      return controller;
    });
