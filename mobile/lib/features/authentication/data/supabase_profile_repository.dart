import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/app_profile.dart';
import 'profile_repository.dart';
import 'supabase_auth_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AppProfile?> loadCurrentProfile() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw const AuthenticationServiceException(
        'An authenticated user is required to load a profile.',
      );
    }

    final row = await _client
        .from('profiles')
        .select('id, display_name, onboarding_completed_at')
        .eq('id', currentUser.id)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return AppProfile.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<AppProfile> completeProfile({required String displayName}) async {
    final row = await _client
        .rpc(
          'complete_profile',
          params: <String, dynamic>{'p_display_name': displayName},
        )
        .single();

    return AppProfile.fromMap(Map<String, dynamic>.from(row));
  }
}
