import 'dart:async';

import 'package:drift/native.dart';
import 'package:praise/features/catalogue_sync/data/catalogue_sync_service.dart';
import 'package:praise/features/catalogue_sync/presentation/catalogue_sync_providers.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/core/database/app_database.dart';
import 'package:praise/features/songs/data/song_repository.dart';
import 'package:praise/features/songs/presentation/song_providers.dart';

class PendingPage {
  PendingPage(this.search, this.offset);
  final String search;
  final int offset;
  final result = Completer<List<SongIndexEntry>>();
}

class ControlledRepository implements SongRepository {
  final requests = <PendingPage>[];
  @override
  Future<List<SongIndexEntry>> fetchSongIndexPage({
    String search = '',
    required int limit,
    required int offset,
  }) {
    final request = PendingPage(search, offset);
    requests.add(request);
    return request.result.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class LocalSync implements CatalogueSyncService {
  LocalSync(this.database);
  final AppDatabase database;
  @override
  Future<CatalogueSyncResult> sync({
    CatalogueSyncProgressCallback? onProgress,
  }) async {
    final now = DateTime.utc(2026);
    await database
        .into(database.songs)
        .insert(
          SongsCompanion.insert(
            id: 'synced',
            title: 'Synced title',
            body: 'Lyrics',
            createdAt: now,
            updatedAt: now,
          ),
        );
    return const CatalogueSyncResult(
      outcome: CatalogueSyncOutcome.updated,
      catalogueVersion: 1,
      songCount: 1,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> waitForIndex(
  ProviderContainer container,
  bool Function(PagedSongsState) matches,
) async {
  for (var i = 0; i < 200; i++) {
    final value = container.read(pagedSongsProvider).valueOrNull;
    if (value != null && !value.isSearching && matches(value)) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Local index did not refresh');
}

List<SongIndexEntry> rows(String prefix, [int count = 1]) => List.generate(
  count,
  (i) => SongIndexEntry(id: '$prefix$i', title: '$prefix$i', source: 'server'),
);

void main() {
  test('custom CRUD and the sync controller used by Settings refresh the mounted index', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        catalogueSyncServiceProvider.overrideWithValue(LocalSync(database)),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
    container.listen(pagedSongsProvider, (_, next) {});
    await waitForIndex(container, (value) => value.items.isEmpty);
    final repository = container.read(songRepositoryProvider);
    final id = await repository.createCustomSong(
      const SongInput(title: 'Custom title', body: 'Lyrics'),
    );
    await waitForIndex(
      container,
      (value) => value.items.any((song) => song.id == id),
    );
    await repository.updateCustomSong(
      id,
      const SongInput(title: 'Edited title', body: 'Lyrics'),
    );
    await waitForIndex(
      container,
      (value) => value.items.single.title == 'Edited title',
    );
    await repository.deleteCustomSong(id);
    await waitForIndex(container, (value) => value.items.isEmpty);
    await container.read(catalogueSyncControllerProvider.notifier).sync();
    await waitForIndex(container, (value) => value.items.single.id == 'synced');
    // Allow the controller's existing progress-dismiss timer to complete.
    await Future<void>.delayed(const Duration(milliseconds: 700));
  });

  testWidgets(
    'debounces typing, retains rows, rejects stale pages and initial searches, clears immediately',
    (tester) async {
      final repository = ControlledRepository();
      final container = ProviderContainer(
        overrides: [songRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      container.listen(pagedSongsProvider, (_, next) {});
      await tester.pump(const Duration(milliseconds: 1));
      repository.requests.single.result.complete(rows('old', 61));
      await tester.pump();
      final controller = container.read(pagedSongsProvider.notifier);
      final paging = controller.loadMore();
      container.read(songSearchProvider.notifier).state = 'g';
      await tester.pump(const Duration(milliseconds: 150));
      container.read(songSearchProvider.notifier).state = 'grace';
      await tester.pump(const Duration(milliseconds: 249));
      expect(repository.requests.length, 2);
      expect(container.read(pagedSongsProvider).requireValue.items.length, 60);
      repository.requests[1].result.complete(rows('stalePage'));
      await paging;
      expect(
        container.read(pagedSongsProvider).requireValue.isSearching,
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(repository.requests.last.search, 'grace');
      container.read(songSearchProvider.notifier).state = 'holy';
      await tester.pump(const Duration(milliseconds: 250));
      repository.requests.last.result.complete(rows('holy'));
      await tester.pump();
      repository.requests[2].result.complete(rows('staleSearch'));
      await tester.pump();
      expect(
        container.read(pagedSongsProvider).requireValue.items.single.id,
        'holy0',
      );
      container.read(songSearchProvider.notifier).state = '';
      expect(repository.requests.last.search, '');
      repository.requests.last.result.complete(rows('all'));
      await tester.pump();
      expect(container.read(pagedSongsProvider).requireValue.search, '');
      expect(
        container.read(pagedSongsProvider).requireValue.items.single.id,
        'all0',
      );
    },
  );

  testWidgets(
    'page failure retains rows and retries the same offset; shared revision refreshes index',
    (tester) async {
      final repository = ControlledRepository();
      final container = ProviderContainer(
        overrides: [songRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      container.listen(pagedSongsProvider, (_, next) {});
      await tester.pump(const Duration(milliseconds: 1));
      repository.requests.single.result.complete(rows('old', 61));
      await tester.pump();
      final controller = container.read(pagedSongsProvider.notifier);
      final paging = controller.loadMore();
      repository.requests.last.result.completeError(
        StateError('offline query failure'),
      );
      await paging;
      expect(container.read(pagedSongsProvider).requireValue.items.length, 60);
      expect(container.read(pagedSongsProvider).requireValue.error, isNotNull);
      final retry = controller.retry();
      expect(repository.requests.last.offset, 60);
      repository.requests.last.result.complete(rows('next'));
      await retry;
      expect(container.read(pagedSongsProvider).requireValue.items.length, 61);
      container.read(songIndexRevisionProvider.notifier).state++;
      expect(repository.requests.last.offset, 0);
      repository.requests.last.result.complete(rows('updated'));
      await tester.pump();
      expect(
        container.read(pagedSongsProvider).requireValue.items.single.id,
        'updated0',
      );
    },
  );
}
