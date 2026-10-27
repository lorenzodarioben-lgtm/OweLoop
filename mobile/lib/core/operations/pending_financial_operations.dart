import 'dart:convert';

import 'client_operation_id.dart';

enum FinancialOperationStatus { pending, unknown, confirmed, rejected }

class PendingFinancialOperation {
  const PendingFinancialOperation({
    required this.id,
    required this.accountId,
    required this.type,
    required this.groupId,
    required this.payload,
    required this.status,
    required this.createdAt,
    this.result,
  });

  final String id, accountId, type, groupId;
  final Map<String, dynamic> payload;
  final FinancialOperationStatus status;
  final DateTime createdAt;
  final Map<String, dynamic>? result;
  bool get unresolved =>
      status == FinancialOperationStatus.pending ||
      status == FinancialOperationStatus.unknown;

  PendingFinancialOperation transition(
    FinancialOperationStatus next, {
    Map<String, dynamic>? result,
  }) => PendingFinancialOperation(
    id: id,
    accountId: accountId,
    type: type,
    groupId: groupId,
    payload: payload,
    status: next,
    createdAt: createdAt,
    result: result ?? this.result,
  );

  Map<String, dynamic> toJson() => {
    'version': 1,
    'id': id,
    'account_id': accountId,
    'type': type,
    'group_id': groupId,
    'payload': payload,
    'status': status.name,
    'created_at': createdAt.toUtc().toIso8601String(),
    'result': result,
  };

  factory PendingFinancialOperation.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported pending submission version.');
    }
    return PendingFinancialOperation(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      type: json['type'] as String,
      groupId: json['group_id'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      status: FinancialOperationStatus.values.byName(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      result: json['result'] == null
          ? null
          : Map<String, dynamic>.from(json['result'] as Map),
    );
  }
}

abstract interface class FinancialOperationStore {
  Future<List<PendingFinancialOperation>> read(String accountId);
  Future<void> write(
    String accountId,
    List<PendingFinancialOperation> operations,
  );
}

abstract interface class FinancialOperationTransport {
  Future<Map<String, dynamic>> submit(
    String type,
    Map<String, dynamic> payload,
    String operationId,
  );
  Future<Map<String, dynamic>?> lookup(String operationId);
  bool isDefinitiveRejection(Object error);
}

class FinancialOperationException implements Exception {
  const FinancialOperationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Persist-before-send. Never interpret a timeout, restart or absent lookup as
/// rejection: an in-flight transaction may still commit. Only explicit retries
/// are sent, always with the saved payload and operation identity.
class PendingFinancialOperations {
  PendingFinancialOperations({
    required this.store,
    required this.transport,
    required this.currentAccountId,
    this.requestTimeout = const Duration(seconds: 30),
  });
  final FinancialOperationStore store;
  final FinancialOperationTransport transport;
  final String? Function() currentAccountId;
  final Duration requestTimeout;
  final Set<String> _busy = {};

  Future<T> _locked<T>(String accountId, Future<T> Function() action) async {
    _check(accountId);
    if (!_busy.add(accountId)) {
      throw const FinancialOperationException(
        'Another submission is being checked. Please wait.',
      );
    }
    try {
      return await action();
    } finally {
      _busy.remove(accountId);
    }
  }

  void _check(String accountId) {
    if (currentAccountId() != accountId) {
      throw const FinancialOperationException(
        'Your session changed. Sign in to the original account to recover this submission.',
      );
    }
  }

  Future<List<PendingFinancialOperation>> load() async {
    final accountId = currentAccountId();
    if (accountId == null) return [];
    final operations = await store.read(accountId);
    _check(accountId);
    if (operations.any((operation) => operation.accountId != accountId)) {
      throw const FinancialOperationException(
        'Saved submissions could not be verified. No request was sent.',
      );
    }
    return operations;
  }

  Future<Map<String, dynamic>> execute({
    required String type,
    required String groupId,
    required Map<String, dynamic> payload,
    String? requestedOperationId,
  }) async {
    final accountId = currentAccountId();
    if (accountId == null) {
      throw const FinancialOperationException('Sign in before submitting.');
    }
    return _locked(
      accountId,
      () => _execute(
        accountId: accountId,
        type: type,
        groupId: groupId,
        payload: payload,
        requestedOperationId: requestedOperationId,
      ),
    );
  }

  // Caller holds the account lock across the entire read/modify/write cycle.
  Future<Map<String, dynamic>> _execute({
    required String accountId,
    required String type,
    required String groupId,
    required Map<String, dynamic> payload,
    String? requestedOperationId,
  }) async {
    _check(accountId);
    final operations = await load();
    _check(accountId);
    final canonical = _normalize(payload);
    final matching = operations
        .where((operation) => operation.id == requestedOperationId)
        .toList();
    if (matching.isNotEmpty &&
        matching.single.status == FinancialOperationStatus.confirmed) {
      final previous = matching.single;
      if (previous.type != type ||
          previous.groupId != groupId ||
          jsonEncode(_normalize(previous.payload)) != jsonEncode(canonical)) {
        throw const FinancialOperationException(
          'This operation identity was already confirmed with a different request.',
        );
      }
      if (previous.result?['id'] != null) return previous.result!;
      throw const FinancialOperationException(
        'This request is already confirmed. Refresh the group to view the record.',
      );
    }
    final pending = operations
        .where(
          (operation) =>
              operation.unresolved &&
              operation.groupId == groupId &&
              operation.type == type,
        )
        .toList();
    if (pending.length > 1) {
      throw const FinancialOperationException(
        'Recover pending submissions before creating another record.',
      );
    }
    late PendingFinancialOperation operation;
    if (pending.isNotEmpty) {
      operation = pending.single;
      if (jsonEncode(_normalize(operation.payload)) != jsonEncode(canonical)) {
        throw const FinancialOperationException(
          'A previous submission has an unknown outcome. Open Pending submissions and resolve it before changing this request.',
        );
      }
    } else {
      operations.removeWhere(
        (entry) =>
            entry.id == requestedOperationId &&
            entry.status == FinancialOperationStatus.rejected,
      );
      operation = PendingFinancialOperation(
        id: requestedOperationId ?? ClientOperationId.generate().value,
        accountId: accountId,
        type: type,
        groupId: groupId,
        payload: canonical,
        status: FinancialOperationStatus.pending,
        createdAt: DateTime.now().toUtc(),
      );
      operations.add(operation);
    }
    // Reaffirm persistence before every send, including an explicit retry after
    // a previous storage/disk-fence failure left only an in-memory cached value.
    await store.write(accountId, operations);
    _check(accountId);
    try {
      final result = await transport
          .submit(type, operation.payload, operation.id)
          .timeout(requestTimeout);
      await _save(
        operations,
        operation.transition(
          FinancialOperationStatus.confirmed,
          result: result,
        ),
      );
      _check(accountId);
      return result;
    } catch (error) {
      // A successful database commit followed by local-storage failure also
      // remains recoverable through the original persisted operation ID.
      // A rejected retry proves nothing about an earlier uncertain attempt.
      // For example, the first call may have committed before membership was
      // revoked. Keep its identity recoverable through caller-only lookup.
      final next = pending.isEmpty && transport.isDefinitiveRejection(error)
          ? FinancialOperationStatus.rejected
          : FinancialOperationStatus.unknown;
      await _save(operations, operation.transition(next));
      if (next == FinancialOperationStatus.rejected) rethrow;
      throw const FinancialOperationException(
        'The outcome is not confirmed. Your request is saved. Open Pending submissions to check or retry the same request safely.',
      );
    }
  }

  Future<void> _save(
    List<PendingFinancialOperation> operations,
    PendingFinancialOperation operation,
  ) async {
    final index = operations.indexWhere((entry) => entry.id == operation.id);
    if (index < 0) {
      throw const FinancialOperationException(
        'Saved operation is unavailable.',
      );
    }
    operations[index] = operation;
    // Keep all unresolved requests and a bounded recent outcome history.
    final completed = operations.where((entry) => !entry.unresolved).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await store.write(operation.accountId, [
      ...operations.where((entry) => entry.unresolved),
      ...completed.take(30),
    ]);
  }

  Future<bool> reconcile(String operationId) async {
    final accountId = currentAccountId();
    if (accountId == null) {
      throw const FinancialOperationException('Sign in before recovering.');
    }
    return _locked(accountId, () async {
      final operations = await load();
      final operation = operations.singleWhere(
        (entry) => entry.id == operationId,
      );
      _check(operation.accountId);
      final result = await transport
          .lookup(operation.id)
          .timeout(requestTimeout);
      _check(operation.accountId);
      if (result == null) return false;
      if (result['group_id'] != operation.groupId ||
          result['operation_type'] != operation.type) {
        throw const FinancialOperationException(
          'The server result does not match the saved submission.',
        );
      }
      await _save(
        operations,
        operation.transition(
          FinancialOperationStatus.confirmed,
          result: result,
        ),
      );
      return true;
    });
  }

  Future<void> retry(String operationId) async {
    final accountId = currentAccountId();
    if (accountId == null) {
      throw const FinancialOperationException('Sign in before recovering.');
    }
    await _locked(accountId, () async {
      final operation = (await load()).singleWhere(
        (entry) => entry.id == operationId,
      );
      if (!operation.unresolved) {
        throw const FinancialOperationException(
          'This submission already has a confirmed outcome.',
        );
      }
      await _execute(
        accountId: accountId,
        requestedOperationId: operation.id,
        type: operation.type,
        groupId: operation.groupId,
        payload: operation.payload,
      );
    });
  }

  static Map<String, dynamic> _normalize(Map<String, dynamic> payload) {
    dynamic sorted(dynamic value) {
      if (value is Map) {
        final keys = value.keys.cast<String>().toList()..sort();
        return {for (final key in keys) key: sorted(value[key])};
      }
      if (value is List) return value.map(sorted).toList();
      return value;
    }

    final result = Map<String, dynamic>.from(sorted(payload) as Map);
    result.remove('p_operation_id');
    for (final key in ['p_payers', 'p_splits']) {
      if (result[key] is List) {
        (result[key] as List).sort(
          (dynamic a, dynamic b) =>
              (a['member_id'] as String).compareTo(b['member_id'] as String),
        );
      }
    }
    return result;
  }
}
