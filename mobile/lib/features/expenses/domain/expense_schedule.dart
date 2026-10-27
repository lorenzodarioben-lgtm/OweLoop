import 'expense_template.dart';

class ExpenseSchedule {
  ExpenseSchedule.fromMap(Map<String, dynamic> row)
    : id = row['id'] as String,
      name = row['name'] as String,
      templateName = row['template_name'] as String,
      cadence = row['cadence'] as String,
      anchorDate = row['anchor_date'] as String,
      timezone = row['timezone'] as String,
      enabled = row['enabled'] as bool,
      cancelled = row['cancelled_at'] != null,
      canEdit = row['can_edit'] as bool,
      revision = row['revision'] as int,
      nextDate = row['next_due_date'] as String?;
  final String id, name, templateName, cadence, anchorDate, timezone;
  final bool enabled, cancelled, canEdit;
  final int revision;
  final String? nextDate;
}

class ExpenseOccurrence {
  ExpenseOccurrence.fromMap(Map<String, dynamic> row)
    : id = row['id'] as String,
      name = row['name'] as String,
      dueDate = row['due_date'] as String,
      state = row['state'] as String,
      canReview = row['can_review'] as bool,
      expenseId = row['expense_id'] as String?,
      template = ExpenseTemplate(
        id: row['id'] as String,
        name: row['template_name'] as String,
        fields: Map<String, dynamic>.from(row['payload'] as Map),
        updatedAt: DateTime.parse(row['created_at'] as String),
        canEdit: false,
      );
  final String id, name, dueDate, state;
  final bool canReview;
  final String? expenseId;
  final ExpenseTemplate template;
}

class ExpenseSchedulePage {
  const ExpenseSchedulePage(
    this.schedules,
    this.occurrences, {
    this.nextDate,
    this.nextId,
  });
  final List<ExpenseSchedule> schedules;
  final List<ExpenseOccurrence> occurrences;
  final String? nextDate, nextId;
}

String? calendarDateError(String? value) {
  final text = value?.trim() ?? '';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return 'Use YYYY-MM-DD.';
  final date = DateTime.tryParse(text);
  if (date == null ||
      date.toIso8601String().substring(0, 10) != text ||
      date.year < 2000 ||
      date.year > 2100) {
    return 'Enter a calendar date from 2000 through 2100.';
  }
  return null;
}
