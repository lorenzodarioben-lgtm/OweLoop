import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:oweloop/core/operations/export_sharing.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('oweloop-export-test-');
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });
  test(
    'CSV uses UTF8, private account cache, MIME and cancellation cleanup',
    () async {
      String? sharedPath;
      final service = ExportSharing(
        currentAccountId: () => 'account-a',
        temporaryDirectory: () async => root,
        transport: (params) async {
          final file = params.files!.single;
          sharedPath = file.path;
          expect(file.path, startsWith(root.path));
          expect(file.path, contains('account-a'));
          expect(file.mimeType, 'text/csv');
          expect(params.fileNameOverrides!.single, endsWith('.csv'));
          expect(
            utf8.decode(await file.readAsBytes()),
            'Caffè, 9223372036854775807',
          );
          return const ShareResult('', ShareResultStatus.dismissed);
        },
      );
      final result = await service.share(
        accountId: 'account-a',
        document: ExportDocument(
          kind: 'expenses',
          text: 'Caffè, 9223372036854775807',
          isJson: false,
        ),
        origin: const Rect.fromLTWH(0, 0, 50, 50),
      );
      expect(result, ShareResultStatus.dismissed);
      expect(await File(sharedPath!).exists(), isFalse);
      expect(shareOutcomeMessage(result), 'Sharing cancelled.');
    },
  );
  test(
    'JSON handoff retains only a private temporary file and never claims a save',
    () async {
      final service = ExportSharing(
        currentAccountId: () => 'account-a',
        temporaryDirectory: () async => root,
        transport: (params) async {
          expect(params.files!.single.mimeType, 'application/json');
          expect(params.fileNameOverrides!.single, endsWith('.json'));
          return const ShareResult('', ShareResultStatus.unavailable);
        },
      );
      final status = await service.share(
        accountId: 'account-a',
        document: ExportDocument(
          kind: 'personal-data',
          text: '{"amount_minor":"9223372036854775807"}',
          isJson: true,
        ),
        origin: const Rect.fromLTWH(0, 0, 50, 50),
      );
      expect(shareOutcomeMessage(status), contains('did not report'));
      expect(root.listSync(recursive: true).whereType<File>().length, 1);
      await service.clearAccount('account-a');
      expect(root.listSync(recursive: true).whereType<File>(), isEmpty);
    },
  );
  test('account switch and invalid kind cannot disclose a file', () async {
    var account = 'account-a';
    var calls = 0;
    final service = ExportSharing(
      currentAccountId: () => account,
      temporaryDirectory: () async {
        account = 'account-b';
        return root;
      },
      transport: (params) async {
        calls++;
        return const ShareResult('', ShareResultStatus.success);
      },
    );
    await expectLater(
      service.share(
        accountId: 'account-a',
        document: ExportDocument(
          kind: 'expenses',
          text: 'private',
          isJson: false,
        ),
        origin: const Rect.fromLTWH(0, 0, 50, 50),
      ),
      throwsStateError,
    );
    expect(calls, 0);
    expect(root.listSync(recursive: true).whereType<File>(), isEmpty);
  });
}
