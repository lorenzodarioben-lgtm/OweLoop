import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('private beta two-account journey', (tester) async {
    // The real journey needs two isolated accounts and a hosted beta project.
    // Its controlled execution steps live in docs/private-beta-test-plan.md.
  }, skip: true);
}
