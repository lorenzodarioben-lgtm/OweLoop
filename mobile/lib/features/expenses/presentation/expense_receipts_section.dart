import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/state/authentication_providers.dart';
import '../data/receipts_repository.dart';

class ExpenseReceiptsSection extends ConsumerStatefulWidget {
  const ExpenseReceiptsSection({required this.expenseId, super.key});
  final String expenseId;
  @override
  ConsumerState<ExpenseReceiptsSection> createState() =>
      _ExpenseReceiptsSectionState();
}

class _ExpenseReceiptsSectionState
    extends ConsumerState<ExpenseReceiptsSection> {
  ReceiptSnapshot? _snapshot;
  ReceiptUpload? _pending;
  Uint8List? _image;
  bool _busy = false, _loading = true;
  String? _message;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  bool _current(int generation, String? account) =>
      mounted &&
      generation == _generation &&
      ref.read(authenticationControllerProvider).state.user?.id == account;
  void _clearImage() {
    final bytes = _image;
    if (bytes != null) ResizeImage(MemoryImage(bytes), width: 2048).evict();
    _image = null;
  }

  Future<void> _load() async {
    if (!mounted) return;
    final account = ref.read(authenticationControllerProvider).state.user?.id;
    if (account == null) {
      setState(() => _loading = false);
      return;
    }
    final generation = _generation;
    setState(() => _loading = true);
    try {
      final result = await ref
          .read(receiptsRepositoryProvider)
          .load(widget.expenseId);
      if (!_current(generation, account)) return;
      setState(() {
        _snapshot = result;
        _message = null;
        if (result.receipts.any(
          (r) => r.id == _pending?.id && r.state == 'ready',
        )) {
          _pending = null;
        }
      });
    } catch (_) {
      if (_current(generation, account)) {
        setState(
          () => _message =
              'Receipts could not refresh. Displayed state may be stale. Check your access and connection.',
        );
      }
    } finally {
      if (_current(generation, account)) setState(() => _loading = false);
    }
  }

  Future<void> _upload({bool retry = false}) async {
    if (_busy) return;
    final account = ref.read(authenticationControllerProvider).state.user?.id;
    final generation = _generation;
    if (account == null) return;
    setState(() => _busy = true);
    try {
      if (!retry) {
        final file = await ref.read(receiptPickerProvider)();
        if (!_current(generation, account) || file == null) return;
        final selected = await ReceiptUpload.read(file);
        if (!_current(generation, account)) return;
        _pending = selected;
      }
      final upload = _pending;
      if (upload == null || !_current(generation, account)) return;
      await ref
          .read(receiptsRepositoryProvider)
          .upload(widget.expenseId, upload);
      if (!_current(generation, account)) return;
      _pending = null;
      await _load();
    } catch (error) {
      if (_current(generation, account)) {
        setState(
          () => _message = error is FormatException
              ? error.message.toString()
              : 'Upload outcome is unknown. Refresh or retry the same selected file. No expense was posted.',
        );
      }
    } finally {
      if (_current(generation, account)) setState(() => _busy = false);
    }
  }

  Future<void> _view(ExpenseReceipt receipt) async {
    final account = ref.read(authenticationControllerProvider).state.user?.id;
    final generation = _generation;
    setState(() => _busy = true);
    try {
      final bytes = await ref
          .read(receiptsRepositoryProvider)
          .download(receipt);
      if (!_current(generation, account)) return;
      if (bytes.length > maxReceiptBytes) {
        throw const FormatException('Receipt exceeds the supported limit.');
      }
      setState(() {
        _clearImage();
        _image = bytes;
      });
    } catch (_) {
      if (_current(generation, account)) {
        setState(
          () => _message =
              'Receipt could not be opened. Refresh to check current access.',
        );
      }
    } finally {
      if (_current(generation, account)) setState(() => _busy = false);
    }
  }

  Future<void> _delete(ExpenseReceipt receipt) async {
    final account = ref.read(authenticationControllerProvider).state.user?.id;
    final generation = _generation;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete this receipt?'),
        content: const Text(
          'The file is removed and an audit event remains. Financial history stays unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Delete receipt'),
          ),
        ],
      ),
    );
    if (confirmed != true || !_current(generation, account)) return;
    setState(() => _busy = true);
    try {
      await ref.read(receiptsRepositoryProvider).delete(receipt.id);
      if (!_current(generation, account)) return;
      setState(_clearImage);
      await _load();
    } catch (_) {
      if (_current(generation, account)) {
        setState(
          () => _message =
              'Deletion outcome is unknown. Refresh or retry deletion.',
        );
      }
    } finally {
      if (_current(generation, account)) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    _clearImage();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      authenticationControllerProvider.select((value) => value.state.user?.id),
      (previous, next) {
        if (previous != next) {
          _generation++;
          setState(() {
            _clearImage();
            _pending = null;
            _snapshot = null;
            _message = null;
            _busy = false;
            _loading = false;
          });
          if (next != null) Future.microtask(_load);
        }
      },
    );
    final disabled = _loading || _busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text('Private receipts', style: Theme.of(context).textTheme.titleLarge),
        const Text(
          'PNG/JPEG, up to 4 MiB and 4096 pixels per side. Shared group members can read ready receipts. Voiding retains them; deletion keeps an audit event.',
        ),
        if (disabled) const LinearProgressIndicator(),
        if (_message != null)
          Semantics(liveRegion: true, child: Text(_message!)),
        Wrap(
          children: [
            TextButton(
              onPressed: disabled ? null : _load,
              child: const Text('Refresh receipts'),
            ),
            if (_snapshot?.canUpload == true && _pending == null)
              TextButton(
                onPressed: disabled || _message != null
                    ? null
                    : () => _upload(),
                child: const Text('Attach receipt image'),
              ),
            if (_pending != null)
              TextButton(
                onPressed: disabled ? null : () => _upload(retry: true),
                child: const Text('Retry same upload'),
              ),
            if (_pending != null)
              TextButton(
                onPressed: disabled
                    ? null
                    : () => setState(() => _pending = null),
                child: const Text('Discard local selection'),
              ),
          ],
        ),
        if (_snapshot != null && _snapshot!.receipts.isEmpty)
          const Text('No receipts attached.'),
        for (final entry
            in (_snapshot?.receipts ?? <ExpenseReceipt>[]).asMap().entries)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Receipt ${entry.key + 1}: ${entry.value.state}'),
              Wrap(
                children: [
                  if (entry.value.state == 'ready')
                    TextButton(
                      onPressed: disabled || _message != null
                          ? null
                          : () => _view(entry.value),
                      child: Text('View receipt ${entry.key + 1}'),
                    ),
                  if (entry.value.canDelete)
                    TextButton(
                      onPressed: disabled || _message != null
                          ? null
                          : () => _delete(entry.value),
                      child: Text(
                        entry.value.state == 'deleting'
                            ? 'Retry deletion'
                            : 'Delete receipt ${entry.key + 1}',
                      ),
                    ),
                ],
              ),
            ],
          ),
        if (_image != null) ...[
          Image.memory(
            _image!,
            cacheWidth: 2048,
            semanticLabel: 'Private receipt image',
            errorBuilder: (_, error, stack) =>
                const Text('This image could not be decoded.'),
          ),
          TextButton(
            onPressed: () => setState(_clearImage),
            child: const Text('Close receipt image'),
          ),
        ],
      ],
    );
  }
}
