import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/custom_songs/presentation/custom_song_editor_screen.dart';
import '../features/custom_songs/data/scanned_song_draft.dart';
import '../features/custom_songs/presentation/scan_song_screen.dart';
import '../features/collections/presentation/collection_detail_screen.dart';
import '../features/collections/presentation/collection_link_handler.dart';
import '../features/collections/presentation/collections_screen.dart';
import '../features/collections/presentation/add_songs_screen.dart';
import '../features/favorites/presentation/favorites_screen.dart';
import '../features/songs/presentation/song_detail_screen.dart';
import '../features/songs/presentation/songs_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../shared/presentation/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/songs',
    overridePlatformDefaultLocation: true,
    redirect: (context, state) {
      final uri = state.uri;
      final isCollectionAppLink = uri.scheme == 'praise' && uri.host == 'list';
      final isCollectionWebLink =
          uri.scheme == 'https' &&
          uri.host == 'nani-samireddy.github.io' &&
          uri.path == '/praise-catalog/list';
      return isCollectionAppLink || isCollectionWebLink ? '/songs' : null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return CollectionLinkHandler(
            child: AppShell(navigationShell: navigationShell),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/songs',
                builder: (context, state) => const SongsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      return SongDetailScreen(
                        songId: state.pathParameters['id']!,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/favorites',
                builder: (context, state) => const FavoritesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/lists',
                builder: (context, state) => const CollectionsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => CollectionDetailScreen(
                      collectionId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'add',
                        builder: (context, state) => AddSongsScreen(
                          collectionId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/custom-song/new',
        builder: (context, state) => CustomSongEditorScreen(
          scannedDraft: state.extra is ScannedSongDraft
              ? state.extra! as ScannedSongDraft
              : null,
        ),
      ),
      GoRoute(
        path: '/custom-song/scan',
        builder: (context, state) => const ScanSongScreen(),
      ),
      GoRoute(
        path: '/custom-song/:id/edit',
        builder: (context, state) =>
            CustomSongEditorScreen(songId: state.pathParameters['id']!),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
