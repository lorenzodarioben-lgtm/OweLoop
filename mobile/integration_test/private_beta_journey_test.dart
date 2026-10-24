import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oweloop/app/app_bootstrap.dart';
import 'package:oweloop/core/operations/client_operation_id.dart';

// Native-device smoke test using disposable local accounts, never hosted data.
const _url = String.fromEnvironment('OWELOOP_TEST_SUPABASE_URL');
const _key = String.fromEnvironment('OWELOOP_TEST_ANON_KEY');
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real local backend: native UI and independent multi-account lifecycle',
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
      final b = SupabaseClient(
        _url,
        _key,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final c = SupabaseClient(
        _url,
        _key,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(() async {
        await b.dispose();
        await c.dispose();
      });
      final bAuth = await b.auth.signUp(
        email: 'device-b-$suffix@example.com',
        password: password,
      );
      await b.rpc(
        'complete_profile',
        params: {'p_display_name': 'Device second account'},
      );
      await c.auth.signUp(
        email: 'device-c-$suffix@example.com',
        password: password,
      );
      await c.rpc(
        'complete_profile',
        params: {'p_display_name': 'Device claiming account'},
      );
      expect((await c.from('groups').select('id').eq('id', groupId)), isEmpty);
      await client.rpc(
        'create_group_invitation',
        params: {'p_group_id': groupId, 'p_recipient_email': bAuth.user!.email},
      );
      final invitation = (await b.rpc('get_pending_group_invitations') as List)
          .firstWhere((dynamic row) => row['group_id'] == groupId);
      await b.rpc(
        'accept_group_invitation',
        params: {'p_invitation_id': invitation['invitation_id']},
      );
      final members =
          await client.rpc(
                'get_group_member_snapshot',
                params: {'p_group_id': groupId},
              )
              as List;
      final aMember = members.firstWhere(
        (dynamic row) => row['user_id'] == registered.user!.id,
      )['id'];
      final bMember = members.firstWhere(
        (dynamic row) => row['user_id'] == bAuth.user!.id,
      )['id'];
      final guest = members.firstWhere(
        (dynamic row) => row['user_id'] == null,
      )['id'];
      final before =
          await b.rpc(
                'get_group_balance_snapshot',
                params: {'p_group_id': groupId},
              )
              as List;
      final multi = await client
          .rpc(
            'create_categorized_expense',
            params: {
              'p_group_id': groupId,
              'p_description': 'Native multi-payer transport',
              'p_total_amount_minor': 1000,
              'p_occurred_at': DateTime.now().toUtc().toIso8601String(),
              'p_operation_id': ClientOperationId.generate().value,
              'p_category_key': 'transport',
              'p_payers': [
                {'member_id': aMember, 'amount_minor': 600},
                {'member_id': bMember, 'amount_minor': 400},
              ],
              'p_splits': [
                {'member_id': bMember, 'amount_minor': 700},
                {'member_id': guest, 'amount_minor': 300},
              ],
            },
          )
          .single();
      await expectLater(
        b.rpc('void_expense', params: {'p_expense_id': multi['id']}),
        throwsA(isA<PostgrestException>()),
      );
      await client.rpc('void_expense', params: {'p_expense_id': multi['id']});
      final after =
          await client.rpc(
                'get_group_balance_snapshot',
                params: {'p_group_id': groupId},
              )
              as List;
      Map<String, int> amounts(List rows) => {
        for (final dynamic row in rows)
          row['group_member_id'] as String: row['net_balance_minor'] as int,
      };
      expect(
        amounts(after),
        amounts(before),
        reason:
            'Voiding reverses exact multi-payer/non-equal financial effects.',
      );
      await b.rpc(
        'record_settlement',
        params: {
          'p_group_id': groupId,
          'p_paying_member_id': guest,
          'p_receiving_member_id': aMember,
          'p_amount_minor': 1,
          'p_settled_at': DateTime.now().toUtc().toIso8601String(),
          'p_operation_id': ClientOperationId.generate().value,
        },
      );
      expect(
        (await b.rpc(
                  'get_filtered_settlement_page',
                  params: {
                    'p_group_id': groupId,
                    'p_paying_member_id': guest,
                    'p_state': 'active',
                  },
                )
                as List)
            .length,
        1,
      );
      final snapshot =
          await b.rpc(
                'get_group_expense_export_snapshot',
                params: {'p_group_id': groupId},
              )
              as List;
      expect(snapshot.length, 2);
      expect(
        snapshot.every(
          (dynamic row) => (row['expense_payers'] as List).isNotEmpty,
        ),
        isTrue,
      );
      expect(
        (await b.rpc(
                  'get_categorized_expense_page',
                  params: {
                    'p_group_id': groupId,
                    'p_category_key': 'transport',
                    'p_query': 'Native multi',
                    'p_limit': 1,
                  },
                )
                as List)
            .length,
        1,
      );
      await client.rpc(
        'create_guest_claim_request',
        params: {
          'p_group_id': groupId,
          'p_guest_member_id': guest,
          'p_recipient_email': c.auth.currentUser!.email,
        },
      );
      final claim = (await c.rpc('get_pending_guest_claim_requests') as List)
          .firstWhere((dynamic row) => row['group_id'] == groupId);
      await c.rpc(
        'accept_guest_claim_request',
        params: {'p_claim_request_id': claim['claim_request_id']},
      );
      final claimed =
          await c.rpc(
                'get_group_member_snapshot',
                params: {'p_group_id': groupId},
              )
              as List;
      expect(
        claimed.any(
          (dynamic row) =>
              row['id'] == guest && row['user_id'] == c.auth.currentUser!.id,
        ),
        isTrue,
      );
      await client.rpc(
        'save_expense_template',
        params: {
          'p_group_id': groupId,
          'p_name': 'Native reviewed template',
          'p_payload': {
            'description': 'Reviewed cost',
            'amount': '10.00',
            'split_method': 'equal',
            'single_payer': aMember,
            'participant_ids': [aMember, bMember, guest],
          },
        },
      );
      expect(
        (await b.rpc('get_expense_templates', params: {'p_group_id': groupId})
                as List)
            .length,
        1,
      );
      await client.rpc('archive_group', params: {'p_group_id': groupId});
      expect(
        (await client.rpc('get_account_deletion_blockers') as List).any(
          (dynamic row) => (row['reason'] as String).contains('reopen'),
        ),
        isTrue,
      );
      await expectLater(
        b.rpc('reopen_group', params: {'p_group_id': groupId}),
        throwsA(isA<PostgrestException>()),
      );
      await client.rpc('reopen_group', params: {'p_group_id': groupId});
      expect(
        client.auth.currentUser!.id,
        registered.user!.id,
        reason: 'Independent accounts never replace the app session.',
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
