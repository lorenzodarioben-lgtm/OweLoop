class AppProfile {
  const AppProfile({
    required this.id,
    required this.displayName,
    required this.onboardingCompletedAt,
  });

  final String id;
  final String displayName;
  final DateTime? onboardingCompletedAt;

  bool get hasCompletedOnboarding => onboardingCompletedAt != null;

  factory AppProfile.fromMap(Map<String, dynamic> map) {
    final onboardingValue = map['onboarding_completed_at'];

    return AppProfile(
      id: map['id'] as String,
      displayName: map['display_name'] as String,
      onboardingCompletedAt: onboardingValue is String
          ? DateTime.tryParse(onboardingValue)
          : onboardingValue as DateTime?,
    );
  }
}
