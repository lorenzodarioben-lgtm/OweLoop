import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oweloop/app/app_bootstrap.dart';

// Native-device smoke test using disposable local accounts, never hosted data.
const _url = String.fromEnvironment('OWELOOP_TEST_SUPABASE_URL');
const _key = String.fromEnvironment('OWELOOP_TEST_ANON_KEY');
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real local backend: group, guest, expense and back navigation',
    (tester) async {
      expect(
        ['localhost', '127.0.0.1', '10.0.2.2', '::1'],
        contains(Uri.parse(_url).host),
        reason: 'Hosted endpoints are forbidden.',
      );
      await Supabase.initialize(url: _url, publishableKey: _key);
      final client = Supabase.instance.client;
      final suffix =
          '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}';
      final password =
          'Local-${List.generate(32, (_) => Random.secure().nextInt(16).toRadixString(16)).join()}';
      final registered = await client.auth.signUp(
        email: 'oweloop-device-$suffix@example.com',
        password: password,
      );
      expect(
        registered.session,
        isNotNull,
        reason: 'Local confirmations must be disabled.',
      );
      await client.rpc(
        'complete_profile',
        params: {'p_display_name': 'Device tester'},
      );
      await tester.pumpWidget(const ProviderScope(child: OweLoopBootstrap()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create group').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'Device journey $suffix',
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AUD').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create group'));
      await tester.pumpAndSettle();
      expect(find.text('Group details'), findsOneWidget);
      await tester.tap(find.text('Add guest'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Device guest');
      await tester.tap(find.widgetWithText(FilledButton, 'Add guest'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add expense').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Device shared dinner',
      );
      await tester.enterText(find.byType(TextFormField).at(1), '9.01');
      await tester.pump();
      final post = find.widgetWithText(FilledButton, 'Post expense');
      await tester.ensureVisible(post);
      await tester.tap(post);
      await tester.pumpAndSettle();
      expect(find.text('Expense details'), findsOneWidget);
      final groups = await client
          .from('groups')
          .select('id')
          .eq('name', 'Device journey $suffix');
      final groupId = groups.single['id'] as String;
      final expenses = await client
          .from('expenses')
          .select('id,total_amount_minor,status')
          .eq('group_id', groupId);
      expect(expenses, hasLength(1));
      expect(expenses.single['total_amount_minor'], 901);
      expect(expenses.single['status'], 'posted');
      final balances = await client.rpc(
        'get_group_balances',
        params: {'p_group_id': groupId},
      );
      expect(
        (balances as List).fold<int>(
          0,
          (sum, dynamic row) => sum + (row['net_balance_minor'] as int),
        ),
        0,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Group details'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('OweLoop'), findsOneWidget);
      await client.auth.signOut();
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsWidgets);
    },
    skip: _url.isEmpty || _key.isEmpty,
  );
}
