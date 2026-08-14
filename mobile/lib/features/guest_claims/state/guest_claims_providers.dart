import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../authentication/state/authentication_controller.dart';
import '../../authentication/state/authentication_providers.dart';
import '../../authentication/state/authentication_state.dart';
import '../data/guest_claims_repository.dart';
import '../data/supabase_guest_claims_repository.dart';
import 'guest_claims_controller.dart';

final guestClaimsRepositoryProvider = Provider<GuestClaimsRepository>((ref) {
  return SupabaseGuestClaimsRepository(Supabase.instance.client);
});

final guestClaimInboxControllerProvider =
    ChangeNotifierProvider.autoDispose<GuestClaimInboxController>((ref) {
      final controller = GuestClaimInboxController(
        ref.watch(guestClaimsRepositoryProvider),
      );
      ref.listen<AuthenticationState>(
        authenticationControllerProvider.select(
          (AuthenticationController controller) => controller.state,
        ),
        (_, next) {
          if (next.status == AuthenticationStatus.authenticated) {
            unawaited(controller.load());
          } else {
            controller.clear();
          }
        },
        fireImmediately: true,
      );
      return controller;
    });

final groupGuestClaimsControllerProvider = ChangeNotifierProvider.autoDispose
    .family<GroupGuestClaimsController, String>((ref, groupId) {
      final controller = GroupGuestClaimsController(
        groupId: groupId,
        repository: ref.watch(guestClaimsRepositoryProvider),
      );
      ref.listen<AuthenticationState>(
        authenticationControllerProvider.select(
          (AuthenticationController controller) => controller.state,
        ),
        (_, next) {
          if (next.status == AuthenticationStatus.authenticated) {
            unawaited(controller.load());
          } else {
            controller.clear();
          }
        },
        fireImmediately: true,
      );
      return controller;
    });
