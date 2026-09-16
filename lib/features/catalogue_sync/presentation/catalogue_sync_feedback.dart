import '../data/catalogue_sync_service.dart';

String catalogueSyncSuccessMessage(CatalogueSyncResult result) {
  if (result.outcome == CatalogueSyncOutcome.upToDate) {
    return 'Your song library is up to date.';
  }
  final conflicts = result.skippedCustomConflicts;
  if (conflicts > 0) {
    return 'Updated ${result.songCount} songs. Kept $conflicts custom '
        'song ID conflict${conflicts == 1 ? '' : 's'}.';
  }
  return 'Updated ${result.songCount} songs.';
}

String catalogueSyncErrorMessage(Object error) {
  if (error is CatalogueSyncException) return error.message;
  return 'Couldn’t update the song library. Your saved songs are unchanged.';
}
