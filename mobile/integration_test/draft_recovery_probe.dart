// DEBUG-only companion to the existing process probe. Credentials stay in the
// device secure store and are never emitted in markers or host artifacts.
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oweloop/core/operations/client_operation_id.dart';
import 'package:oweloop/core/operations/financial_operations_providers.dart';
import 'package:oweloop/core/operations/pending_financial_operations.dart';
import 'package:oweloop/core/operations/secure_storage_durability.dart';
import 'package:oweloop/features/expenses/data/expense_draft_store.dart';
import 'package:oweloop/features/expenses/domain/expense_draft_review.dart';

void _require(bool value) {
  if (!value) throw StateError('Draft recovery invariant failed');
}

Future<void> runDraftRecoveryProbe(
  SupabaseClient client,
  String phase,
  void Function(String) marker,
  void Function(String) stage,
) async {
  const storage = FlutterSecureStorage();
  final drafts = SecureExpenseDraftStore(storage);
  final operations = SecureFinancialOperationStore(storage);
  const probeKey = 'oweloop.debug.draft_probe.v1';
  if (phase == 'draft') {
    await client.auth.signOut();
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final password =
        'Local-${List.generate(40, (_) => Random.secure().nextInt(16).toRadixString(16)).join()}';
    final a = 'draft-a-$suffix@example.com';
    final b = 'draft-b-$suffix@example.com';
    await client.auth.signUp(email: b, password: password);
    final bId = client.auth.currentUser!.id;
    await client.rpc('complete_profile', params: {'p_display_name': 'Draft B'});
    await client.auth.signOut();
    await client.auth.signUp(email: a, password: password);
    final account = client.auth.currentUser!.id;
    await client.rpc('complete_profile', params: {'p_display_name': 'Draft A'});
    final group = await client
        .rpc(
          'create_group',
          params: {
            'p_name': 'Disposable draft probe',
            'p_currency_code': 'AUD',
          },
        )
        .single();
    final groupId = group['id'] as String;
    final members =
        await client.rpc(
              'get_group_member_snapshot',
              params: {'p_group_id': groupId},
            )
            as List;
    final owner = members.single['id'] as String;
    final guest = await client
        .rpc(
          'add_guest_member',
          params: {'p_group_id': groupId, 'p_display_name': 'Draft guest'},
        )
        .single();
    final removed = guest['id'] as String;
    final fields = <String, dynamic>{
      'description': 'Unposted recovery probe',
      'amount': '12.34',
      'occurred_on': '2026-10-24T00:00:00.000',
      'category_key': 'groceries',
      'split_method': 'exact',
      'multiple_payers': false,
      'single_payer': removed,
      'payer_ids': [removed],
      'participant_ids': [owner, removed],
      'payer_amounts': {removed: '12.34'},
      'split_values': {owner: '4.00', removed: '8.34'},
    };
    final pending = PendingFinancialOperation(
      id: ClientOperationId.generate().value,
      accountId: account,
      type: 'expense',
      groupId: groupId,
      payload: {'probe': 'unsent'},
      status: FinancialOperationStatus.unknown,
      createdAt: DateTime.utc(2026),
    );
    await operations.write(account, [pending]);
    await drafts.write(account, groupId, fields);
    await storage.write(
      key: probeKey,
      value: jsonEncode({
        'a': a,
        'b': b,
        'b_id': bId,
        'password': password,
        'account': account,
        'group': groupId,
        'removed': removed,
        'fields': fields,
        'pending': pending.toJson(),
      }),
    );
    await flushSecureStorage();
    _require(
      (await client.from('expenses').select('id').eq('group_id', groupId))
          .isEmpty,
    );
    marker('WAIT:draft');
    await Completer<void>().future;
    return;
  }
  stage('fixture');
  final encodedFixture = await storage.read(key: probeKey);
  if (encodedFixture == null) throw StateError('Probe fixture did not survive');
  final fixture = jsonDecode(encodedFixture) as Map<String, dynamic>;
  final account = fixture['account'] as String;
  final group = fixture['group'] as String;
  _require(client.auth.currentUser?.id == account);
  stage('restore');
  final restored = await drafts.read(account, group);
  _require(jsonEncode(restored) == jsonEncode(fixture['fields']));
  _require(!restored!.containsKey('operation_id'));
  // Removal happens after the real restart, before the explicit form review.
  stage('remove');
  await client.rpc(
    'remove_group_member',
    params: {'p_group_id': group, 'p_member_id': fixture['removed']},
  );
  stage('members');
  final members =
      await client.rpc(
            'get_group_member_snapshot',
            params: {'p_group_id': group},
          )
          as List;
  final active = members
      .where((dynamic m) => m['removed_at'] == null)
      .map((dynamic m) => m['id'] as String)
      .toSet();
  stage('review');
  final reviewed = ExpenseDraftReview(restored, active);
  _require(reviewed.fields['single_payer'] == null);
  _require((reviewed.fields['participant_ids'] as List).length == 1);
  _require(reviewed.removedIds.contains(fixture['removed']));
  _require((reviewed.fields['split_values'] as Map).values.single == '4.00');
  stage('switch_b');
  await client.auth.signOut();
  _require(client.auth.currentUser == null);
  await client.auth.signInWithPassword(
    email: fixture['b'] as String,
    password: fixture['password'] as String,
  );
  _require(await drafts.read(fixture['b_id'] as String, group) == null);
  await drafts.deleteAccount(fixture['b_id'] as String);
  stage('switch_a');
  await client.auth.signOut();
  await client.auth.signInWithPassword(
    email: fixture['a'] as String,
    password: fixture['password'] as String,
  );
  _require(
    jsonEncode(await drafts.read(account, group)) ==
        jsonEncode(fixture['fields']),
  );
  await drafts.deleteAccount(account);
  stage('cleanup');
  _require(await drafts.read(account, group) == null);
  _require(
    jsonEncode((await operations.read(account)).single.toJson()) ==
        jsonEncode(fixture['pending']),
  );
  _require(
    (await client.from('expenses').select('id').eq('group_id', group)).isEmpty,
  );
  await storage.delete(key: probeKey);
  await flushSecureStorage();
  marker('PASS:resume-draft');
}
