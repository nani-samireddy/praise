import '../data/catalogue_sync_service.dart';

String catalogueSyncSuccessMessage(CatalogueSyncResult result) {
  if (result.outcome == CatalogueSyncOutcome.upToDate) {
    return 'Catalogue is already up to date.';
  }
  final conflicts = result.skippedCustomConflicts;
  if (conflicts > 0) {
    return 'Updated ${result.songCount} songs. Preserved $conflicts custom '
        'song ID conflict${conflicts == 1 ? '' : 's'}.';
  }
  return 'Updated ${result.songCount} songs.';
}

String catalogueSyncErrorMessage(Object error) {
  if (error is CatalogueSyncException) return error.message;
  return 'Catalogue refresh failed. Your saved songs were not changed.';
}
