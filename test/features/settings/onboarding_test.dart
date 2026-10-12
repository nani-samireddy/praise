import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/app/router.dart';
import 'package:praise/core/database/app_database.dart';
import 'package:praise/features/settings/data/feature_flags.dart';
import 'package:praise/features/settings/presentation/feature_providers.dart';
import 'package:praise/features/settings/presentation/starter_screen.dart';

void main() {
  test(
    'role change replaces custom switches and commits one complete state',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final store = FeatureSettingsStore(db);
      await store.set(store.key(FeatureKey.adaptiveSongControls), 'true');
      await store.complete(PrimaryRole.singer);
      expect(await store.watchRole().first, PrimaryRole.singer);

      expect(await store.watchOnboarding().first, isTrue);
      for (final feature in FeatureKey.values) {
        expect(
          await store.watchFeature(feature).first,
          roleDefaults(PrimaryRole.singer).contains(feature),
        );
      }
      await store.complete(PrimaryRole.musician);
      expect(await store.watchFeature(FeatureKey.metronome).first, isTrue);
      expect(PrimaryRole.worshipLeader.label, 'Worship leader');
    },
  );

  test('failed role save rolls back role, switches and onboarding', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = FeatureSettingsStore(db);
    await store.complete(PrimaryRole.singer);
    await db.customStatement(
      "CREATE TRIGGER reject_feature BEFORE INSERT ON app_metadata WHEN NEW.key = 'feature_metronome_enabled' BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await expectLater(store.complete(PrimaryRole.musician), throwsA(anything));
    expect(await store.watchRole().first, PrimaryRole.singer);
    expect(await store.watchFeature(FeatureKey.metronome).first, isFalse);
    expect(await store.watchOnboarding().first, isTrue);
  });

  for (final size in [
    const Size(320, 568),
    const Size(568, 320),
    const Size(320, 240),
  ]) {
    testWidgets('roles and Continue remain reachable at $size and 200% text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const StarterScreen(),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Singer'));
      await tester.tap(find.text('Singer'));
      await tester.pump();
      final semantics = tester.ensureSemantics();
      expect(
        tester
            .getSemantics(find.byType(ListTile).first)
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      semantics.dispose();
      await tester.ensureVisible(find.text('Continue'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    });
  }

  testWidgets('role tiles support keyboard activation', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: StarterScreen())),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'first launch redirects, completed onboarding allows explicit change and cancel',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() => db.customSelect('SELECT 1').get());
      addTearDown(() => tester.runAsync(db.close));
      final saveStore = _RecordingStore(db);
      final onboarding = StreamController<bool>();
      addTearDown(onboarding.close);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          featureSettingsStoreProvider.overrideWithValue(saveStore),
          onboardingCompleteProvider.overrideWith((ref) => onboarding.stream),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(routerProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      onboarding.add(false);
      await tester.pumpAndSettle();
      expect(find.byType(StarterScreen), findsOneWidget);
      onboarding.add(true);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/songs');
      router.go('/starter');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/songs');
      router.go('/starter?change=true');
      await tester.pumpAndSettle();
      expect(find.text('Choose your role'), findsOneWidget);
      await tester.tap(find.byTooltip('Cancel role change'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/settings');
      router.go('/starter?change=true');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Musician'));
      await tester.pump();
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/settings');
      expect(saveStore.savedRole, PrimaryRole.musician);
    },
  );
}

class _RecordingStore extends FeatureSettingsStore {
  _RecordingStore(super.database);
  PrimaryRole? savedRole;
  @override
  Future<void> complete(PrimaryRole role) async {
    savedRole = role;
  }
}
