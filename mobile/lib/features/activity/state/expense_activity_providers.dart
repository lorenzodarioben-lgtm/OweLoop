import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../authentication/state/authentication_controller.dart';
import '../../authentication/state/authentication_providers.dart';
import '../../authentication/state/authentication_state.dart';
import '../data/expense_activity_repository.dart';
import '../data/supabase_expense_activity_repository.dart';
import 'expense_activity_controller.dart';

final expenseActivityRepositoryProvider = Provider<ExpenseActivityRepository>((
  ref,
) {
  return SupabaseExpenseActivityRepository(Supabase.instance.client);
});

final expenseActivityControllerProvider = ChangeNotifierProvider.autoDispose
    .family<
      ExpenseActivityController,
      ({String expenseId, String currencyCode})
    >((ref, request) {
      final controller = ExpenseActivityController(
        expenseId: request.expenseId,
        currencyCode: request.currencyCode,
        repository: ref.watch(expenseActivityRepositoryProvider),
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
