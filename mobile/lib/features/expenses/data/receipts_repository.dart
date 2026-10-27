import 'dart:convert';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/operations/client_operation_id.dart';

const maxReceiptBytes = 4 * 1024 * 1024;

class ReceiptUpload {
  ReceiptUpload({required this.id, required this.bytes, required this.mime});
  final String id, mime;
  final Uint8List bytes;
  static Future<ReceiptUpload> read(XFile file) async {
    if (await file.length() > maxReceiptBytes) {
      throw const FormatException('Receipt exceeds 4 MiB.');
    }
    final name = file.name.toLowerCase();
    final mime = name.endsWith('.png')
        ? 'image/png'
        : name.endsWith('.jpg') || name.endsWith('.jpeg')
        ? 'image/jpeg'
        : null;
    final buffer = BytesBuilder(copy: false);
    await for (final chunk in file.openRead()) {
      if (buffer.length + chunk.length > maxReceiptBytes) {
        throw const FormatException('Receipt exceeds 4 MiB.');
      }
      buffer.add(chunk);
    }
    final bytes = buffer.takeBytes();
    if (mime == null || bytes.isEmpty || bytes.length > maxReceiptBytes) {
      throw const FormatException('Choose a PNG or JPEG up to 4 MiB.');
    }
    final signature = mime == 'image/png'
        ? [137, 80, 78, 71, 13, 10, 26, 10]
        : [255, 216, 255];
    if (bytes.length < signature.length ||
        !signature.asMap().entries.every((e) => bytes[e.key] == e.value)) {
      throw const FormatException(
        'File content does not match its image extension.',
      );
    }
    return ReceiptUpload(
      id: ClientOperationId.generate().value,
      bytes: bytes,
      mime: mime,
    );
  }
}

class ExpenseReceipt {
  ExpenseReceipt.fromMap(Map<String, dynamic> row)
    : id = row['id'] as String,
      path = row['object_key'] as String,
      state = row['state'] as String,
      mime = row['mime_type'] as String,
      canDelete = row['can_delete'] as bool;
  final String id, path, state, mime;
  final bool canDelete;
}

class ReceiptSnapshot {
  const ReceiptSnapshot(this.receipts, {required this.canUpload});
  final List<ExpenseReceipt> receipts;
  final bool canUpload;
}

abstract interface class ReceiptsRepository {
  Future<ReceiptSnapshot> load(String expenseId);
  Future<void> upload(String expenseId, ReceiptUpload upload);
  Future<Uint8List> download(ExpenseReceipt receipt);
  Future<void> delete(String receiptId);
}

class SupabaseReceiptsRepository implements ReceiptsRepository {
  SupabaseReceiptsRepository(this.client);
  final SupabaseClient client;
  @override
  Future<ReceiptSnapshot> load(String expenseId) async {
    final result =
        await client
                .rpc(
                  'get_expense_receipts',
                  params: {'p_expense_id': expenseId},
                )
                .timeout(const Duration(seconds: 30))
            as Map;
    return ReceiptSnapshot(
      (result['receipts'] as List)
          .map(
            (dynamic row) =>
                ExpenseReceipt.fromMap(Map<String, dynamic>.from(row as Map)),
          )
          .toList(),
      canUpload: result['can_upload'] as bool,
    );
  }

  Future<void> _gateway(Map<String, dynamic> body, String state) async {
    final response = await client.functions
        .invoke('receipts', body: body)
        .timeout(const Duration(seconds: 60));
    if (response.status != 200 ||
        response.data is! Map ||
        response.data['state'] != state) {
      throw StateError('Receipt outcome is unconfirmed.');
    }
  }

  @override
  Future<void> upload(String expenseId, ReceiptUpload upload) => _gateway({
    'action': 'upload',
    'receipt_id': upload.id,
    'expense_id': expenseId,
    'mime_type': upload.mime,
    'data_base64': base64Encode(upload.bytes),
  }, 'ready');
  @override
  Future<Uint8List> download(ExpenseReceipt receipt) => client.storage
      .from('oweloop-receipts')
      .download(receipt.path)
      .timeout(const Duration(seconds: 30));
  @override
  Future<void> delete(String receiptId) =>
      _gateway({'action': 'delete', 'receipt_id': receiptId}, 'deleted');
}

final receiptsRepositoryProvider = Provider<ReceiptsRepository>(
  (ref) => SupabaseReceiptsRepository(Supabase.instance.client),
);
final receiptsEnabledProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('OWELOOP_RECEIPTS_ENABLED'),
);
final receiptPickerProvider = Provider<Future<XFile?> Function()>(
  (ref) =>
      () => openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Receipt image',
            extensions: ['png', 'jpg', 'jpeg'],
            mimeTypes: ['image/png', 'image/jpeg'],
            uniformTypeIdentifiers: ['public.png', 'public.jpeg'],
          ),
        ],
      ),
);
