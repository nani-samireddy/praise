import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/network_providers.dart';
import '../data/catalogue_remote_data_source.dart';
import '../data/catalogue_store.dart';
import '../data/catalogue_sync_service.dart';

final catalogueStoreProvider = Provider<CatalogueStore>((ref) {
  return CatalogueStore(ref.watch(databaseProvider));
});

final catalogueRemoteDataSourceProvider = Provider<CatalogueRemoteDataSource>((
  ref,
) {
  return DioCatalogueRemoteDataSource(ref.watch(dioProvider));
});

final catalogueSyncServiceProvider = Provider<CatalogueSyncService>((ref) {
  return CatalogueSyncService(
    manifestUrl: AppConfig.catalogueManifestUrl,
    remote: ref.watch(catalogueRemoteDataSourceProvider),
    store: ref.watch(catalogueStoreProvider),
  );
});

final catalogueStatusProvider = StreamProvider<CatalogueStatus>((ref) {
  return ref.watch(catalogueStoreProvider).watchStatus();
});

final catalogueSyncProgressProvider = StateProvider<CatalogueSyncProgress?>(
  (ref) => null,
);

final catalogueSyncControllerProvider =
    AsyncNotifierProvider<CatalogueSyncController, CatalogueSyncResult?>(
      CatalogueSyncController.new,
    );

class CatalogueSyncController extends AsyncNotifier<CatalogueSyncResult?> {
  @override
  FutureOr<CatalogueSyncResult?> build() => null;

  Future<CatalogueSyncResult> sync() async {
    ref
        .read(catalogueSyncProgressProvider.notifier)
        .state = const CatalogueSyncProgress(
      message: 'Preparing catalogue refresh…',
      progress: 0,
    );
    state = const AsyncLoading();
    try {
      final result = await ref
          .read(catalogueSyncServiceProvider)
          .sync(
            onProgress: (progress) {
              ref.read(catalogueSyncProgressProvider.notifier).state = progress;
            },
          );
      ref
          .read(catalogueSyncProgressProvider.notifier)
          .state = CatalogueSyncProgress(
        message: result.outcome == CatalogueSyncOutcome.upToDate
            ? 'Catalogue is up to date.'
            : 'Catalogue refresh complete.',
        progress: 1,
      );
      state = AsyncData(result);
      return result;
    } on Object catch (error, stackTrace) {
      ref.read(catalogueSyncProgressProvider.notifier).state = null;
      state = AsyncError(error, stackTrace);
      rethrow;
    } finally {
      Future<void>.delayed(const Duration(milliseconds: 650), () {
        if (ref.read(catalogueSyncControllerProvider).isLoading) return;
        ref.read(catalogueSyncProgressProvider.notifier).state = null;
      });
    }
  }
}
