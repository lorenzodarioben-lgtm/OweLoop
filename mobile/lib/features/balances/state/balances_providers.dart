import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../authentication/state/authentication_controller.dart';
import '../../authentication/state/authentication_providers.dart';
import '../../authentication/state/authentication_state.dart';
import '../data/balances_repository.dart';
import '../data/supabase_balances_repository.dart';
import 'balances_controller.dart';

final balancesRepositoryProvider = Provider<BalancesRepository>((ref) {
  return SupabaseBalancesRepository(Supabase.instance.client);
});

final groupBalancesControllerProvider = ChangeNotifierProvider.autoDispose
    .family<GroupBalancesController, ({String groupId, String currencyCode})>((
      ref,
      request,
    ) {
      final controller = GroupBalancesController(
        groupId: request.groupId,
        currencyCode: request.currencyCode,
        repository: ref.watch(balancesRepositoryProvider),
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
