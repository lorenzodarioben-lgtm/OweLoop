import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/operations/financial_operations_providers.dart';

import '../../authentication/state/authentication_controller.dart';
import '../../authentication/state/authentication_providers.dart';
import '../../authentication/state/authentication_state.dart';
import '../data/settlements_repository.dart';
import '../data/supabase_settlements_repository.dart';
import 'settlements_controller.dart';

final settlementsRepositoryProvider = Provider<SettlementsRepository>((ref) {
  return SupabaseSettlementsRepository(
    Supabase.instance.client,
    operations: ref.watch(pendingFinancialOperationsProvider),
  );
});

final settlementHistoryControllerProvider = ChangeNotifierProvider.autoDispose
    .family<
      SettlementHistoryController,
      ({String groupId, String currencyCode})
    >((ref, request) {
      final controller = SettlementHistoryController(
        groupId: request.groupId,
        currencyCode: request.currencyCode,
        repository: ref.watch(settlementsRepositoryProvider),
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

final settlementCreationControllerProvider =
    ChangeNotifierProvider.autoDispose<SettlementCreationController>((ref) {
      final controller = SettlementCreationController(
        ref.watch(settlementsRepositoryProvider),
      );
      ref.listen<AuthenticationState>(
        authenticationControllerProvider.select(
          (AuthenticationController controller) => controller.state,
        ),
        (_, next) {
          if (next.status != AuthenticationStatus.authenticated) {
            controller.clear();
          }
        },
        fireImmediately: true,
      );
      return controller;
    });
