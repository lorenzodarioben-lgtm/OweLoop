import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/core/operations/client_operation_id.dart';

void main() {
  test('creates high-entropy UUID version 4 operation identifiers', () {
    final operationIds = List.generate(
      20,
      (_) => ClientOperationId.generate().value,
    );

    expect(operationIds.toSet(), hasLength(operationIds.length));
    for (final operationId in operationIds) {
      expect(
        operationId,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    }
  });
}
