class ExpenseTemplate {
  const ExpenseTemplate({
    required this.id,
    required this.name,
    required this.fields,
    required this.updatedAt,
    required this.canEdit,
  });
  final String id, name;
  final Map<String, dynamic> fields;
  final DateTime updatedAt;
  final bool canEdit;
  factory ExpenseTemplate.fromMap(Map<String, dynamic> row) => ExpenseTemplate(
    id: row['id'] as String,
    name: row['name'] as String,
    fields: Map<String, dynamic>.from(row['payload'] as Map),
    updatedAt: DateTime.parse(row['updated_at'] as String),
    canEdit: row['can_edit'] as bool? ?? false,
  );
}
