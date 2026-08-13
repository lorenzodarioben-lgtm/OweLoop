import 'package:oweloop/features/expenses/data/expenses_repository.dart';
import 'package:oweloop/features/expenses/domain/exact_money.dart';
import 'package:oweloop/features/expenses/domain/expense_models.dart';

class FakeExpensesRepository implements ExpensesRepository {
  FakeExpensesRepository({
    List<ExpenseRecord>? expenses,
    Map<String, ExpenseRecord>? expensesById,
    this.createdExpense,
  }) : expenses = expenses ?? [],
       expensesById = expensesById ?? {};

  List<ExpenseRecord> expenses;
  Map<String, ExpenseRecord> expensesById;
  ExpenseRecord? createdExpense;
  Object? loadExpensesError;
  Object? createExpenseError;
  Object? loadExpenseError;
  Future<List<ExpenseRecord>> Function()? loadExpensesHandler;
  Future<ExpenseRecord> Function(ExpenseCreationInput input)? createHandler;
  int loadExpensesCalls = 0;
  ExpenseCreationInput? lastCreationInput;

  @override
  Future<List<ExpenseRecord>> loadPostedExpenses(String groupId) async {
    loadExpensesCalls += 1;
    if (loadExpensesHandler != null) {
      return loadExpensesHandler!();
    }
    if (loadExpensesError != null) {
      throw loadExpensesError!;
    }
    return List<ExpenseRecord>.from(expenses);
  }

  @override
  Future<ExpenseRecord> createExpense(ExpenseCreationInput input) async {
    lastCreationInput = input;
    if (createHandler != null) {
      return createHandler!(input);
    }
    if (createExpenseError != null) {
      throw createExpenseError!;
    }
    return createdExpense ??
        (throw StateError('No created expense was configured for this test.'));
  }

  @override
  Future<ExpenseRecord?> loadAccessibleExpense(String expenseId) async {
    if (loadExpenseError != null) {
      throw loadExpenseError!;
    }
    return expensesById[expenseId];
  }
}

final testExpense = ExpenseRecord(
  id: 'expense-1',
  groupId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  description: 'Dinner',
  total: ExactMoney(currencyCode: 'AUD', minorUnits: 1000),
  occurredAt: DateTime.utc(2026, 7, 29, 12),
  status: ExpenseStatus.posted,
  payers: [
    ExpensePayer(
      memberId: 'owner-member',
      displayName: 'Taylor',
      amount: ExactMoney(currencyCode: 'AUD', minorUnits: 1000),
    ),
  ],
  splits: [
    ExpenseSplit(
      memberId: 'guest-member',
      displayName: 'Morgan',
      amount: ExactMoney(currencyCode: 'AUD', minorUnits: 500),
    ),
    ExpenseSplit(
      memberId: 'owner-member',
      displayName: 'Taylor',
      amount: ExactMoney(currencyCode: 'AUD', minorUnits: 500),
    ),
  ],
);
