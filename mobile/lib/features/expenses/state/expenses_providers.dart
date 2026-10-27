import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/operations/financial_operations_providers.dart';

import '../../authentication/state/authentication_controller.dart';
import '../../authentication/state/authentication_providers.dart';
import '../../authentication/state/authentication_state.dart';
import '../data/expenses_repository.dart';
import '../data/supabase_expenses_repository.dart';
import 'expenses_controller.dart';

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  return SupabaseExpensesRepository(
    Supabase.instance.client,
    operations: ref.watch(pendingFinancialOperationsProvider),
  );
});

final allExpenseHistoryControllerProvider = ChangeNotifierProvider.autoDispose
    .family<ExpenseHistoryController, String>((ref, groupId) {
      final controller = ExpenseHistoryController(
        groupId: groupId,
        repository: ref.watch(expensesRepositoryProvider),
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

final expenseHistoryControllerProvider = ChangeNotifierProvider.autoDispose
    .family<ExpenseHistoryController, String>((ref, groupId) {
      final controller = ExpenseHistoryController(
        groupId: groupId,
        repository: ref.watch(expensesRepositoryProvider),
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

final expenseCreationControllerProvider =
    ChangeNotifierProvider.autoDispose<ExpenseCreationController>((ref) {
      final controller = ExpenseCreationController(
        ref.watch(expensesRepositoryProvider),
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

final expenseDetailControllerProvider = ChangeNotifierProvider.autoDispose
    .family<ExpenseDetailController, ({String groupId, String expenseId})>((
      ref,
      request,
    ) {
      final controller = ExpenseDetailController(
        groupId: request.groupId,
        expenseId: request.expenseId,
        repository: ref.watch(expensesRepositoryProvider),
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
