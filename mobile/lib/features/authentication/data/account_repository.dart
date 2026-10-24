import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AccountRepository {
  Future<Map<String, dynamic>> exportPersonalData();
  Future<List<String>> deletionBlockers();
  Future<void> deleteAccount(String password);
}

class SupabaseAccountRepository implements AccountRepository {
  SupabaseAccountRepository(this.client);
  final SupabaseClient client;
  @override
  Future<Map<String, dynamic>> exportPersonalData() async =>
      Map<String, dynamic>.from(
        await client.rpc('export_personal_data') as Map,
      );
  @override
  Future<List<String>> deletionBlockers() async {
    final rows = await client.rpc('get_account_deletion_blockers');
    return (rows as List)
        .map((dynamic row) => '${row['group_name']}: ${row['reason']}')
        .toList();
  }

  @override
  Future<void> deleteAccount(String password) async {
    final response = await client.functions.invoke(
      'delete-account',
      body: {'password': password},
    );
    if (response.status != 200 ||
        response.data is! Map ||
        response.data['deleted'] != true) {
      throw const AccountOperationException(
        'Account deletion is not confirmed. Check your connection and account status before retrying.',
      );
    }
    // Auth may already have removed the server session. Clear the local copy.
    try {
      await client.auth.signOut(scope: SignOutScope.local);
    } on AuthException {
      /* deleted user */
    }
  }
}

class AccountOperationException implements Exception {
  const AccountOperationException(this.message);
  final String message;
}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => SupabaseAccountRepository(Supabase.instance.client),
);
