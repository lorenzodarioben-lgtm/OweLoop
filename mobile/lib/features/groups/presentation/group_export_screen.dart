import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/state/authentication_providers.dart';
import '../../expenses/domain/ledger_csv.dart';
import '../../expenses/state/expenses_providers.dart';
import '../../settlements/state/settlements_providers.dart';
import '../state/groups_providers.dart';
import '../../../core/operations/export_sharing.dart';

class GroupExportScreen extends ConsumerStatefulWidget {
  const GroupExportScreen({required this.groupId, super.key});
  final String groupId;
  @override
  ConsumerState<GroupExportScreen> createState() => _GroupExportScreenState();
}

class _GroupExportScreenState extends ConsumerState<GroupExportScreen> {
  bool _busy = false;
  String? _csv, _message;
  String _kind = 'expenses';
  Future<void> _export(bool settlements) async {
    final accountId = ref.read(authenticationControllerProvider).state.user?.id;
    final group = ref
        .read(groupDetailControllerProvider(widget.groupId))
        .state
        .group;
    if (accountId == null || group == null || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _csv = null;
      _kind = settlements ? 'settlements' : 'expenses';
    });
    try {
      final text = settlements
          ? LedgerCsv.settlements(
              await ref
                  .read(settlementsRepositoryProvider)
                  .loadGroupSettlements(
                    groupId: group.id,
                    currencyCode: group.currencyCode,
                  ),
            )
          : LedgerCsv.expenses(
              await ref
                  .read(expensesRepositoryProvider)
                  .loadPostedExpenses(group.id),
            );
      if (mounted &&
          ref.read(authenticationControllerProvider).state.user?.id ==
              accountId) {
        setState(() => _csv = text);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'The complete export could not be loaded. No partial export is shown. Check your access and connection, then retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Export group ledger')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Each export reads one complete server snapshot, including voided records. Amounts are exact integer minor units; currency and allocations are included. Copy the CSV or share a temporary private file using your device. Spreadsheet formulas are escaped.',
          ),
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton(
                onPressed: _busy ? null : () => _export(false),
                child: const Text('Expense CSV'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _export(true),
                child: const Text('Settlement CSV'),
              ),
            ],
          ),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (_message != null) Text(_message!),
          if (_csv != null) ...[
            Builder(
              builder: (buttonContext) => TextButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        final account = ref
                            .read(authenticationControllerProvider)
                            .state
                            .user
                            ?.id;
                        if (account == null) return;
                        final box =
                            buttonContext.findRenderObject()! as RenderBox;
                        setState(() => _busy = true);
                        try {
                          final result = await ref
                              .read(exportSharingProvider)
                              .share(
                                accountId: account,
                                document: ExportDocument(
                                  kind: _kind,
                                  text: _csv!,
                                  isJson: false,
                                ),
                                origin:
                                    box.localToGlobal(Offset.zero) & box.size,
                              );
                          if (mounted) {
                            setState(
                              () => _message = shareOutcomeMessage(result),
                            );
                          }
                        } catch (_) {
                          if (mounted) {
                            setState(
                              () => _message =
                                  'Sharing could not complete. No destination save is confirmed.',
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                icon: const Icon(Icons.share),
                label: const Text('Share CSV file'),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _csv!));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'CSV copied. Store the exported financial data privately.',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy CSV'),
            ),
            SelectableText(_csv!),
          ],
        ],
      ),
    ),
  );
}
