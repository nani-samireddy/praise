import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/core/database/app_database.dart';
import 'package:praise/features/collections/presentation/collection_providers.dart';
import 'package:praise/features/performance/presentation/performance_screen.dart';
import 'package:praise/features/performance/presentation/performance_session.dart';
import 'package:praise/features/settings/data/settings_repository.dart';
import 'package:praise/features/settings/data/telugu_font.dart';
import 'package:praise/features/settings/presentation/settings_providers.dart';
import 'package:praise/features/songs/presentation/song_providers.dart';

class Awake implements ScreenAwake {
  final calls = <bool>[];
  @override
  Future<void> setEnabled(bool enabled) async => calls.add(enabled);
}

Song song(String id) => Song(
  id: id,
  title: 'Song $id',
  body: List.filled(80, 'ప్రభువా నా పాట').join('\n'),
  source: 'server',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  isDeleted: false,
);

void main() {
  testWidgets(
    'live order, scroll memory, temporary sizing, back and lifecycle',
    (tester) async {
      final awake = Awake();
      final order = StreamController<List<Song>>();
      final a = song('a');
      final b = song('b');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            screenAwakeProvider.overrideWithValue(awake),
            collectionSongsProvider('list').overrideWith((ref) => order.stream),
            songProvider('a').overrideWith((ref) => Stream.value(a)),
            songProvider('b').overrideWith((ref) => Stream.value(b)),
            lyricsFontSizeProvider.overrideWith((ref) => Stream.value(19)),
            lyricsDisplayModeProvider.overrideWith(
              (ref) => Stream.value(LyricsDisplayMode.primary),
            ),
            teluguFontProvider.overrideWith(
              (ref) => Stream.value(TeluguFont.system),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const PerformanceScreen(
                        songId: 'a',
                        collectionId: 'list',
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      expect(awake.calls, isEmpty);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      order.add([a, b]);
      await tester.pumpAndSettle();
      expect(awake.calls.last, true);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Previous song',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      final offset = tester
          .widget<ListView>(find.byType(ListView))
          .controller!
          .offset;
      await tester.tap(find.byTooltip('Larger lyrics'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Next song',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Song b'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Next song',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Previous song',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<ListView>(find.byType(ListView)).controller!.offset,
        closeTo(offset, 1),
      );
      order.add([b, a]);
      await tester.pumpAndSettle();
      expect(find.text('2 of 2'), findsOneWidget);
      order.add([b]);
      await tester.pumpAndSettle();
      expect(find.text('Continue from first song'), findsOneWidget);
      await tester.tap(find.text('Continue from first song'));
      await tester.pumpAndSettle();
      expect(find.text('Song b'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(awake.calls.last, false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(awake.calls.last, true);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(awake.calls.last, false);
      expect(find.text('Open'), findsOneWidget);
      await order.close();
    },
  );

  testWidgets('missing song keeps exit and capability failure visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          screenAwakeProvider.overrideWithValue(UnsupportedAwake()),
          songProvider('gone').overrideWith((ref) => Stream.value(null)),
          lyricsFontSizeProvider.overrideWith((ref) => Stream.value(19)),
          lyricsDisplayModeProvider.overrideWith(
            (ref) => Stream.value(LyricsDisplayMode.primary),
          ),
          teluguFontProvider.overrideWith(
            (ref) => Stream.value(TeluguFont.system),
          ),
        ],
        child: const MaterialApp(home: PerformanceScreen(songId: 'gone')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('This song is no longer available.'), findsOneWidget);
    expect(
      find.text('Keep awake unavailable. Your screen may sleep.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Exit performance mode'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}

class UnsupportedAwake implements ScreenAwake {
  @override
  Future<void> setEnabled(bool enabled) async =>
      throw UnsupportedError('unsupported');
}
