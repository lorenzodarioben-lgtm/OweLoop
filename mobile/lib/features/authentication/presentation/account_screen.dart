import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/account_repository.dart';
import '../state/authentication_providers.dart';
import '../validation/auth_validators.dart';
import '../../../core/operations/financial_operations_providers.dart';
import '../../expenses/data/expense_draft_store.dart';
import '../../../core/operations/export_sharing.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});
  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _busy = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    _name.text =
        ref.read(authenticationControllerProvider).state.profile?.displayName ??
        '';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final accountId = ref.read(authenticationControllerProvider).state.user?.id;
    if (accountId == null) return;
    setState(() => _busy = true);
    try {
      final data = await ref
          .read(accountRepositoryProvider)
          .exportPersonalData();
      // Minor-unit fields are decimal strings so tools with narrower numeric
      // ranges can import the JSON without losing financial precision.
      dynamic exact(dynamic value) {
        if (value is Map) {
          return {
            for (final entry in value.entries)
              entry.key: entry.key.toString().endsWith('_minor')
                  ? entry.value.toString()
                  : exact(entry.value),
          };
        }
        if (value is List) return value.map(exact).toList();
        return value;
      }

      final text = const JsonEncoder.withIndent('  ').convert(exact(data));
      if (mounted &&
          ref.read(authenticationControllerProvider).state.user?.id ==
              accountId) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: const Text('Personal data export'),
                actions: [
                  Builder(
                    builder: (buttonContext) => IconButton(
                      tooltip: 'Share JSON file',
                      icon: const Icon(Icons.share),
                      onPressed: () async {
                        final box =
                            buttonContext.findRenderObject()! as RenderBox;
                        try {
                          final result = await ref
                              .read(exportSharingProvider)
                              .share(
                                accountId: accountId,
                                document: ExportDocument(
                                  kind: 'personal-data',
                                  text: text,
                                  isJson: true,
                                ),
                                origin:
                                    box.localToGlobal(Offset.zero) & box.size,
                              );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(shareOutcomeMessage(result)),
                              ),
                            );
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Sharing could not complete. No save is confirmed.',
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy JSON export',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: text));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Export copied. Store it privately.'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(text),
              ),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _message =
              'Personal data could not be exported. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final accountId = ref.read(authenticationControllerProvider).state.user?.id;
    if (accountId == null) return;
    setState(() => _busy = true);
    try {
      final blockers = await ref
          .read(accountRepositoryProvider)
          .deletionBlockers();
      if (!mounted) return;
      if (blockers.isNotEmpty) {
        setState(() => _message = blockers.join('\n'));
        return;
      }
      final password = await showDialog<String>(
        context: context,
        builder: (context) => const _DeleteAccountDialog(),
      );
      if (password == null) return;
      await ref.read(accountRepositoryProvider).deleteAccount(password);
      // Keep other accounts' data intact. Clear this account's saved payloads.
      try {
        await ref.read(financialOperationStoreProvider).write(accountId, []);
        await ref.read(expenseDraftStoreProvider).deleteAccount(accountId);
        await ref.read(exportSharingProvider).clearAccount(accountId);
      } catch (_) {
        /* encrypted data remains inaccessible to other accounts */
      }
      ref.read(authenticationControllerProvider).accountDeleted();
    } catch (error) {
      if (mounted) {
        setState(
          () => _message =
              'Deletion is not confirmed. Check ownership, balances, your current password, and the deployed delete-account function before retrying.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authenticationControllerProvider).state;
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(auth.user?.email ?? ''),
            const SizedBox(height: 16),
            Form(
              key: _form,
              child: TextFormField(
                controller: _name,
                enabled: !_busy && !auth.isSubmitting,
                decoration: const InputDecoration(labelText: 'Display name'),
                validator: AuthValidators.displayName,
              ),
            ),
            FilledButton(
              onPressed: _busy || auth.isSubmitting
                  ? null
                  : () async {
                      if (!(_form.currentState?.validate() ?? false)) return;
                      await ref
                          .read(authenticationControllerProvider)
                          .completeProfile(displayName: _name.text);
                      if (mounted) {
                        setState(
                          () => _message =
                              ref
                                  .read(authenticationControllerProvider)
                                  .state
                                  .errorMessage ??
                              'Profile updated. Existing group names remain historical snapshots.',
                        );
                      }
                    },
              child: const Text('Save profile'),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: _busy ? null : _export,
              child: const Text('Export personal data'),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Deleting your account removes account access and de-identifies group memberships. Shared expenses, settlements and audit history are retained. Settle balances and transfer ownership or archive owned groups first.',
              ),
            ),
            OutlinedButton(
              onPressed: _busy ? null : _delete,
              child: const Text('Delete account'),
            ),
            if (_busy) const Center(child: CircularProgressIndicator()),
            if (_message != null)
              Semantics(liveRegion: true, child: Text(_message!)),
          ],
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();
  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Delete account permanently?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Shared financial history is retained. Enter your current password to confirm account deletion.',
        ),
        TextField(
          controller: _password,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(labelText: 'Current password'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _password.text),
        child: const Text('Delete account'),
      ),
    ],
  );
}
