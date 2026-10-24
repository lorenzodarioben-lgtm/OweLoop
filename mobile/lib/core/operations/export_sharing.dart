import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../features/authentication/state/authentication_providers.dart';

class ExportDocument {
  ExportDocument({
    required this.kind,
    required this.text,
    required this.isJson,
  });
  final String kind, text;
  final bool isJson;
  String get mimeType => isJson ? 'application/json' : 'text/csv';
  String filename(DateTime now) =>
      'oweloop-$kind-${now.toUtc().microsecondsSinceEpoch}.${isJson ? 'json' : 'csv'}';
}

/// Only explicit user actions write private temporary files. Never use public
/// storage. Successful/unknown handoffs stay cached for 24h so destinations can
/// finish reading; cancellation deletes immediately. Cleanup touches our own
/// account directory only, without following links or deleting directories.
class ExportSharing {
  ExportSharing({
    required this.currentAccountId,
    Future<Directory> Function()? temporaryDirectory,
    Future<ShareResult> Function(ShareParams)? transport,
  }) : temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       transport = transport ?? SharePlus.instance.share;
  final String? Function() currentAccountId;
  final Future<Directory> Function() temporaryDirectory;
  final Future<ShareResult> Function(ShareParams) transport;
  void _check(String account) {
    if (currentAccountId() != account) {
      throw StateError('Account changed. Generate a new export.');
    }
  }

  Future<Directory> _directory(String account) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(account)) {
      throw const FormatException('Invalid export account.');
    }
    return Directory(
      '${(await temporaryDirectory()).path}${Platform.pathSeparator}oweloop_exports${Platform.pathSeparator}$account',
    );
  }

  Future<void> clearAccount(String account) async {
    final directory = await _directory(account);
    if (await directory.exists()) {
      for (final item in directory.listSync(followLinks: false)) {
        if (item is File) {
          await item.delete();
        }
      }
    }
  }

  Future<ShareResultStatus> share({
    required String accountId,
    required ExportDocument document,
    required Rect origin,
  }) async {
    _check(accountId);
    if (!RegExp(r'^[a-z-]+$').hasMatch(document.kind)) {
      throw const FormatException('Invalid export kind.');
    }
    final bytes = utf8.encode(document.text);
    if (bytes.length > 20 * 1024 * 1024) {
      throw const FormatException('Export exceeds the 20 MB sharing limit.');
    }
    final directory = await _directory(accountId);
    await directory.create(recursive: true);
    for (final item in directory.listSync(followLinks: false)) {
      if (item is File &&
          (await item.lastModified()).isBefore(
            DateTime.now().subtract(const Duration(hours: 24)),
          )) {
        await item.delete();
      }
    }
    _check(accountId);
    final file = File(
      '${directory.path}${Platform.pathSeparator}${document.filename(DateTime.now())}',
    );
    await file.writeAsBytes(bytes, flush: true);
    try {
      _check(accountId);
      final result = await transport(
        ShareParams(
          files: [XFile(file.path, mimeType: document.mimeType)],
          fileNameOverrides: [file.uri.pathSegments.last],
          sharePositionOrigin: origin,
          title: 'OweLoop export',
        ),
      );
      if (result.status == ShareResultStatus.dismissed) await file.delete();
      return result.status;
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }
}

final exportSharingProvider = Provider<ExportSharing>(
  (ref) => ExportSharing(
    currentAccountId: () =>
        ref.read(authenticationControllerProvider).state.user?.id,
  ),
);

String shareOutcomeMessage(ShareResultStatus status) => switch (status) {
  ShareResultStatus.success =>
    'Share sheet completed. Check the destination to confirm saving.',
  ShareResultStatus.dismissed => 'Sharing cancelled.',
  ShareResultStatus.unavailable =>
    'The destination did not report an outcome. Check it before retrying.',
};
