import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../authentication/state/authentication_controller.dart';
import '../../authentication/state/authentication_providers.dart';
import '../../authentication/state/authentication_state.dart';
import '../data/groups_repository.dart';
import '../data/supabase_groups_repository.dart';
import 'groups_controller.dart';

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  return SupabaseGroupsRepository(Supabase.instance.client);
});

final groupsControllerProvider = ChangeNotifierProvider<GroupsController>((
  ref,
) {
  final controller = GroupsController(ref.watch(groupsRepositoryProvider));
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

final groupDetailControllerProvider = ChangeNotifierProvider.autoDispose
    .family<GroupDetailController, String>((ref, groupId) {
      final controller = GroupDetailController(
        groupId: groupId,
        repository: ref.watch(groupsRepositoryProvider),
      );
      ref.listen<AuthenticationState>(
        authenticationControllerProvider.select(
          (controller) => controller.state,
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
