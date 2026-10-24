import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/app/app_bootstrap.dart';
import 'package:oweloop/features/authentication/data/account_repository.dart';
import 'package:oweloop/features/authentication/domain/app_profile.dart';
import 'package:oweloop/features/authentication/state/authentication_providers.dart';
import 'package:oweloop/features/groups/state/groups_providers.dart';
import '../../fakes/authentication_fakes.dart';
import '../../fakes/groups_fakes.dart';

class FakeAccountRepository implements AccountRepository {
  List<String> blockers = [];
  int deletions = 0;
  @override
  Future<List<String>> deletionBlockers() async => blockers;
  @override
  Future<void> deleteAccount(String password) async {
    deletions++;
  }

  @override
  Future<Map<String, dynamic>> exportPersonalData() async => {
    'profile': {'id': testUser.id},
    'created_expenses': [
      {'total_amount_minor': 9223372036854775807},
    ],
  };
}

void main() {
  Future<void> open(
    WidgetTester tester,
    FakeAccountRepository account, {
    FakeProfileRepository? profiles,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(restoredUser: testUser),
          ),
          profileRepositoryProvider.overrideWithValue(
            profiles ??
                FakeProfileRepository(currentProfile: completedTestProfile),
          ),
          groupsRepositoryProvider.overrideWithValue(FakeGroupsRepository()),
          accountRepositoryProvider.overrideWithValue(account),
        ],
        child: const OweLoopBootstrap(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Account and recovery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'profile editing stays on Account and updates the authenticated profile',
    (tester) async {
      final profiles = FakeProfileRepository(
        currentProfile: completedTestProfile,
        completedProfile: AppProfile(
          id: testUser.id,
          displayName: 'Jordan',
          onboardingCompletedAt: DateTime.utc(2026),
        ),
      );
      await open(tester, FakeAccountRepository(), profiles: profiles);
      await tester.enterText(find.byType(TextFormField), 'Jordan');
      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();
      expect(profiles.completedDisplayName, 'Jordan');
      expect(find.text('Account'), findsOneWidget);
      expect(find.textContaining('Profile updated.'), findsOneWidget);
    },
  );
  testWidgets(
    'deletion blockers are shown before any destructive confirmation',
    (tester) async {
      final account = FakeAccountRepository()
        ..blockers = ['Trip: settle this membership balance'];
      await open(tester, account);
      await tester.scrollUntilVisible(
        find.widgetWithText(OutlinedButton, 'Delete account'),
        250,
        scrollable: find
            .ancestor(
              of: find.byType(Form).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Delete account'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('settle this membership balance'),
        findsOneWidget,
      );
      expect(account.deletions, 0);
      expect(find.text('Delete account permanently?'), findsNothing);
    },
  );
  testWidgets(
    'personal JSON export preserves bigint amounts as decimal strings',
    (tester) async {
      await open(tester, FakeAccountRepository());
      await tester.tap(find.text('Export personal data'));
      await tester.pumpAndSettle();
      final text = tester
          .widget<SelectableText>(find.byType(SelectableText))
          .data!;
      expect(text, contains('"total_amount_minor": "9223372036854775807"'));
      expect(text, contains(testUser.id));
    },
  );
}
