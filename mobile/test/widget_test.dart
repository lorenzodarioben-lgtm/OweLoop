import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oweloop/app/app.dart';
import 'package:oweloop/app/router.dart';

void main() {
  testWidgets('renders the project foundation home screen', (tester) async {
    final router = createAppRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(ProviderScope(child: OweLoopApp(router: router)));
    await tester.pumpAndSettle();

    expect(find.text('OweLoop foundation is running'), findsOneWidget);
    expect(find.text('Shared expenses without the friction.'), findsOneWidget);
  });
}
