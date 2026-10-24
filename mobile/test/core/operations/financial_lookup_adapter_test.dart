import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oweloop/core/operations/financial_operations_providers.dart';

void main() {
  for (final fixture in <(String, Object, bool)>[
    ('absent', <Object>[], false),
    (
      'committed',
      [
        {'operation_type': 'expense', 'expense_id': 'record'},
      ],
      false,
    ),
    (
      'ambiguous',
      [
        {'expense_id': 'one'},
        {'expense_id': 'two'},
      ],
      true,
    ),
    ('malformed', {'expense_id': 'record'}, true),
  ]) {
    test(
      'lookup ${fixture.$1} uses table JSON without singular coercion',
      () async {
        final client = SupabaseClient(
          'http://localhost:60421',
          'public-test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.path, '/rest/v1/rpc/get_financial_operation');
            expect(
              request.headers['Accept'],
              isNot(contains('vnd.pgrst.object')),
            );
            expect(jsonDecode(request.body), {'p_operation_id': 'operation'});
            return http.Response(
              jsonEncode(fixture.$2),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(client.dispose);
        final result = SupabaseFinancialOperationTransport(
          client,
        ).lookup('operation');
        if (fixture.$3) {
          await expectLater(result, throwsA(isA<FormatException>()));
        } else {
          expect(
            await result,
            fixture.$1 == 'absent'
                ? isNull
                : {'operation_type': 'expense', 'expense_id': 'record'},
          );
        }
      },
    );
  }
}
