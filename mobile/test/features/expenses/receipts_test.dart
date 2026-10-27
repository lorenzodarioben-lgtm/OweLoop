import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/features/authentication/state/authentication_controller.dart';
import 'package:oweloop/features/authentication/state/authentication_providers.dart';
import 'package:oweloop/features/expenses/data/receipts_repository.dart';
import 'package:oweloop/features/expenses/presentation/expense_receipts_section.dart';
import '../../fakes/authentication_fakes.dart';

final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
XFile file() => XFile.fromData(png, path: 'receipt.png', mimeType: 'image/png');

class ReceiptFake implements ReceiptsRepository {
  final ids = <String>[];
  bool fail = false, ready = false;
  int deleted = 0;
  @override
  Future<ReceiptSnapshot> load(String expenseId) async => ReceiptSnapshot([
    if (ready)
      ExpenseReceipt.fromMap({
        'id': ids.isEmpty ? 'receipt' : ids.last,
        'object_key': 'opaque.png',
        'state': 'ready',
        'mime_type': 'image/png',
        'can_delete': true,
      }),
  ], canUpload: true);
  @override
  Future<void> upload(String expenseId, ReceiptUpload upload) async {
    ids.add(upload.id);
    if (fail) throw StateError('response lost');
    ready = true;
  }

  @override
  Future<Uint8List> download(ExpenseReceipt receipt) async => png;
  @override
  Future<void> delete(String receiptId) async {
    deleted++;
    ready = false;
  }
}

void main() {
  test(
    'bounded file selection verifies extension/content and never creates a financial ID',
    () async {
      final upload = await ReceiptUpload.read(file());
      expect(upload.mime, 'image/png');
      expect(upload.bytes, png);
      await expectLater(
        ReceiptUpload.read(XFile.fromData(png, path: 'receipt.svg')),
        throwsFormatException,
      );
      await expectLater(
        ReceiptUpload.read(
          XFile.fromData(Uint8List(maxReceiptBytes + 1), path: 'receipt.png'),
        ),
        throwsFormatException,
      );
      await expectLater(
        ReceiptUpload.read(
          XFile.fromData(Uint8List.fromList([1, 2, 3]), path: 'receipt.png'),
        ),
        throwsFormatException,
      );
    },
  );
  Future<AuthenticationController> open(
    WidgetTester tester,
    ReceiptFake repo,
    Future<XFile?> Function() picker,
  ) async {
    final auth = AuthenticationController(
      authRepository: FakeAuthRepository(restoredUser: testUser),
      profileRepository: FakeProfileRepository(
        currentProfile: completedTestProfile,
      ),
    );
    await auth.initialize();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authenticationControllerProvider.overrideWith((ref) => auth),
          receiptsRepositoryProvider.overrideWithValue(repo),
          receiptPickerProvider.overrideWithValue(picker),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExpenseReceiptsSection(expenseId: 'expense'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return auth;
  }

  testWidgets('picker cancellation makes no upload', (tester) async {
    final repo = ReceiptFake();
    await open(tester, repo, () async => null);
    await tester.tap(find.text('Attach receipt image'));
    await tester.pumpAndSettle();
    expect(repo.ids, isEmpty);
    expect(find.text('No receipts attached.'), findsOneWidget);
  });
  testWidgets(
    'uncertain upload explicitly retries the same selected identity',
    (tester) async {
      final repo = ReceiptFake()..fail = true;
      await open(tester, repo, () async => file());
      await tester.tap(find.text('Attach receipt image'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Upload outcome is unknown'), findsOneWidget);
      repo.fail = false;
      await tester.tap(find.text('Retry same upload'));
      await tester.pumpAndSettle();
      expect(repo.ids, hasLength(2));
      expect(repo.ids.toSet(), hasLength(1));
      expect(find.text('View receipt 1'), findsOneWidget);
    },
  );
  testWidgets(
    'account change while picker is open discards selected bytes without sending',
    (tester) async {
      final picker = Completer<XFile?>();
      final repo = ReceiptFake();
      final auth = await open(tester, repo, () => picker.future);
      await tester.tap(find.text('Attach receipt image'));
      await tester.pump();
      await auth.signOut();
      await tester.pumpAndSettle();
      picker.complete(file());
      await tester.pumpAndSettle();
      expect(repo.ids, isEmpty);
      expect(find.text('Attach receipt image'), findsNothing);
    },
  );
  testWidgets('delete is confirmed and large receipt text fits a small phone', (
    tester,
  ) async {
    final repo = ReceiptFake()..ready = true;
    await open(tester, repo, () async => null);
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final action = find.text('Delete receipt 1');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(repo.deleted, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete receipt'));
    await tester.pumpAndSettle();
    expect(repo.deleted, 1);
  });
}
