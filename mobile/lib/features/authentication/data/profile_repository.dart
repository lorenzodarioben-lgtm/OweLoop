import '../domain/app_profile.dart';

abstract interface class ProfileRepository {
  Future<AppProfile?> loadCurrentProfile();

  Future<AppProfile> completeProfile({required String displayName});
}
