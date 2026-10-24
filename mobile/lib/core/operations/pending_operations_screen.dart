import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'financial_operations_providers.dart';
import 'pending_financial_operations.dart';

class PendingOperationsScreen extends ConsumerStatefulWidget {
  const PendingOperationsScreen({super.key});
  @override
  ConsumerState<PendingOperationsScreen> createState() =>
      _PendingOperationsScreenState();
}

class _PendingOperationsScreenState
    extends ConsumerState<PendingOperationsScreen> {
  List<PendingFinancialOperation> _operations = [];
  bool _loading = true;
  bool _busy = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final operations = await ref
          .read(pendingFinancialOperationsProvider)
          .load();
      if (mounted) {
        setState(() {
          _operations = operations.reversed.toList();
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message =
              'Saved submissions could not be loaded. No request was sent. Retry after unlocking the device.';
        });
      }
    }
  }

  Future<void> _act(
    PendingFinancialOperation operation, {
    required bool retry,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final service = ref.read(pendingFinancialOperationsProvider);
      if (retry) {
        await service.retry(operation.id);
        _message =
            'The saved request is confirmed. Refresh the group to view the record.';
      } else {
        final confirmed = await service.reconcile(operation.id);
        _message = confirmed
            ? 'The server confirmed this record. Refresh the group to view it.'
            : 'No committed record was found yet. The outcome remains uncertain; retrying sends the same saved request and cannot create a second record with this identity.';
      }
    } catch (error) {
      _message = error is FinancialOperationException
          ? error.message
          : 'We could not confirm this submission. It remains saved; check your connection and try again.';
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Pending submissions'),
      actions: [
        IconButton(
          tooltip: 'Refresh saved submissions',
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'An interrupted request may already have committed. Check its status or retry the saved request. OweLoop never retries automatically.',
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Semantics(liveRegion: true, child: Text(_message!)),
                ),
              if (_operations.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Text('No saved submissions for this account.'),
                ),
              for (final operation in _operations)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        operation.type == 'expense'
                            ? (operation.payload['p_description'] as String? ??
                                  'Expense')
                            : 'Settlement record',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${operation.status == FinancialOperationStatus.pending ? 'outcome unknown' : operation.status.name}\n${operation.createdAt.toLocal()}\nReference: ${operation.id}',
                      ),
                      if (operation.unresolved)
                        Wrap(
                          children: [
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _act(operation, retry: false),
                              child: const Text('Check status'),
                            ),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _act(operation, retry: true),
                              child: const Text('Retry saved request'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          ),
  );
}
