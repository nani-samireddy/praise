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

final catalogueSyncControllerProvider =
    AsyncNotifierProvider<CatalogueSyncController, CatalogueSyncResult?>(
      CatalogueSyncController.new,
    );

class CatalogueSyncController extends AsyncNotifier<CatalogueSyncResult?> {
  @override
  FutureOr<CatalogueSyncResult?> build() => null;

  Future<CatalogueSyncResult> sync() async {
    state = const AsyncLoading();
    try {
      final result = await ref.read(catalogueSyncServiceProvider).sync();
      state = AsyncData(result);
      return result;
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
