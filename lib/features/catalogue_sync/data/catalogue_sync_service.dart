import 'package:dio/dio.dart';

import 'catalogue_models.dart';
import 'catalogue_remote_data_source.dart';
import 'catalogue_store.dart';

enum CatalogueSyncOutcome { updated, upToDate }

class CatalogueSyncProgress {
  const CatalogueSyncProgress({required this.message, required this.progress})
    : assert(progress >= 0 && progress <= 1);

  final String message;
  final double progress;
}

typedef CatalogueSyncProgressCallback = void Function(
  CatalogueSyncProgress progress,
);

class CatalogueSyncResult {
  const CatalogueSyncResult({
    required this.outcome,
    required this.catalogueVersion,
    required this.songCount,
    this.skippedCustomConflicts = 0,
  });

  final CatalogueSyncOutcome outcome;
  final int catalogueVersion;
  final int songCount;
  final int skippedCustomConflicts;
}

class CatalogueSyncException implements Exception {
  const CatalogueSyncException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class CatalogueSyncService {
  CatalogueSyncService({
    required String manifestUrl,
    required this.remote,
    required this.store,
  }) : _manifestUrl = manifestUrl.trim();

  final String _manifestUrl;
  final CatalogueRemoteDataSource remote;
  final CatalogueStore store;
  Future<CatalogueSyncResult>? _activeSync;

  Future<CatalogueSyncResult> sync({
    CatalogueSyncProgressCallback? onProgress,
  }) {
    return _activeSync ??= _performSync(onProgress: onProgress)
        .whenComplete(() => _activeSync = null);
  }

  Future<CatalogueSyncResult> _performSync({
    CatalogueSyncProgressCallback? onProgress,
  }) async {
    if (_manifestUrl.isEmpty) {
      throw const CatalogueSyncException(
        'Catalogue sync is not configured for this build.',
      );
    }
    final manifestUri = Uri.tryParse(_manifestUrl);
    if (manifestUri == null ||
        (manifestUri.scheme != 'https' && manifestUri.scheme != 'http')) {
      throw const CatalogueSyncException(
        'The configured catalogue manifest URL is invalid.',
      );
    }

    try {
      onProgress?.call(
        const CatalogueSyncProgress(
          message: 'Checking catalogue version…',
          progress: 0.08,
        ),
      );
      final manifest = await remote.fetchManifest(manifestUri);
      final localVersion = await store.readCatalogueVersion() ?? 0;
      if (manifest.catalogueVersion <= localVersion) {
        onProgress?.call(
          const CatalogueSyncProgress(
            message: 'Catalogue is already current…',
            progress: 0.92,
          ),
        );
        await store.recordSuccessfulCheck(manifest);
        return CatalogueSyncResult(
          outcome: CatalogueSyncOutcome.upToDate,
          catalogueVersion: manifest.catalogueVersion,
          songCount: manifest.songCount,
        );
      }

      final deltaChain = manifest.deltaChainFrom(localVersion);
      if (deltaChain != null) {
        try {
          final deltas = <CatalogueDelta>[];
          for (final (index, reference) in deltaChain.indexed) {
            final current = index + 1;
            final total = deltaChain.length;
            final downloadProgress = 0.18 + (0.48 * (index / total));
            onProgress?.call(
              CatalogueSyncProgress(
                message: total == 1
                    ? 'Downloading catalogue changes…'
                    : 'Downloading catalogue changes $current of $total…',
                progress: downloadProgress,
              ),
            );
            deltas.add(await remote.fetchDelta(manifestUri, reference));
          }
          onProgress?.call(
            const CatalogueSyncProgress(
              message: 'Applying catalogue changes…',
              progress: 0.78,
            ),
          );
          final applied = await store.applyDeltas(manifest, deltas);
          return CatalogueSyncResult(
            outcome: CatalogueSyncOutcome.updated,
            catalogueVersion: manifest.catalogueVersion,
            songCount: applied.activeSongCount,
            skippedCustomConflicts: applied.skippedCustomConflicts,
          );
        } on CatalogueValidationException {
          // A bad or stale delta must not block refresh when the full snapshot
          // is still available and checksum-protected.
        } on DioException {
          // Fall back to the full snapshot. If the network is actually down,
          // the full fetch below will surface the normal sync error.
        }
      }

      onProgress?.call(
        const CatalogueSyncProgress(
          message: 'Downloading full catalogue…',
          progress: 0.32,
        ),
      );
      final snapshot = await remote.fetchCatalogue(manifestUri, manifest);
      onProgress?.call(
        const CatalogueSyncProgress(
          message: 'Applying catalogue update…',
          progress: 0.78,
        ),
      );
      final applied = await store.apply(snapshot);
      return CatalogueSyncResult(
        outcome: CatalogueSyncOutcome.updated,
        catalogueVersion: manifest.catalogueVersion,
        songCount: applied.activeSongCount,
        skippedCustomConflicts: applied.skippedCustomConflicts,
      );
    } on CatalogueSyncException {
      rethrow;
    } on CatalogueValidationException catch (error) {
      throw CatalogueSyncException(
        'The downloaded catalogue is invalid. Your saved songs were not changed.',
        error,
      );
    } on DioException catch (error) {
      throw CatalogueSyncException(
        'Could not reach the catalogue. Check your connection and try again.',
        error,
      );
    } on Object catch (error) {
      throw CatalogueSyncException(
        'Catalogue refresh failed. Your saved songs were not changed.',
        error,
      );
    }
  }
}
