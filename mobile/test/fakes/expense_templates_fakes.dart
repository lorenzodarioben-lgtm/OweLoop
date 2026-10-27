import 'package:oweloop/features/expenses/data/expense_templates_repository.dart';
import 'package:oweloop/features/expenses/domain/expense_template.dart';

class FakeExpenseTemplatesRepository implements ExpenseTemplatesRepository {
  List<ExpenseTemplate> templates = [];
  Map<String, dynamic>? savedFields;
  String? savedName;
  @override
  Future<List<ExpenseTemplate>> load(String groupId) async => templates;
  @override
  Future<void> save({
    required String groupId,
    required String name,
    required Map<String, dynamic> fields,
    ExpenseTemplate? previous,
  }) async {
    savedName = name;
    savedFields = Map.of(fields);
  }

  @override
  Future<void> delete(ExpenseTemplate template) async {
    templates.removeWhere((value) => value.id == template.id);
  }
}
