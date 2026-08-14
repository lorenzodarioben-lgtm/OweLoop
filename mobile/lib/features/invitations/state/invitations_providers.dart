import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../authentication/state/authentication_controller.dart';
import '../../authentication/state/authentication_providers.dart';
import '../../authentication/state/authentication_state.dart';
import '../data/invitations_repository.dart';
import '../data/supabase_invitations_repository.dart';
import 'invitations_controller.dart';

final invitationsRepositoryProvider = Provider<InvitationsRepository>((ref) {
  return SupabaseInvitationsRepository(Supabase.instance.client);
});

final invitationInboxControllerProvider =
    ChangeNotifierProvider.autoDispose<InvitationInboxController>((ref) {
      final controller = InvitationInboxController(
        ref.watch(invitationsRepositoryProvider),
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

final groupInvitationsControllerProvider = ChangeNotifierProvider.autoDispose
    .family<GroupInvitationsController, String>((ref, groupId) {
      final controller = GroupInvitationsController(
        groupId: groupId,
        repository: ref.watch(invitationsRepositoryProvider),
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
