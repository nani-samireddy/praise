import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/songs/presentation/song_detail_screen.dart';
import '../features/songs/presentation/songs_screen.dart';
import '../shared/presentation/app_shell.dart';
import '../shared/presentation/coming_soon_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/songs',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
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
                builder: (context, state) => const ComingSoonScreen(
                  title: 'Favorites',
                  icon: Icons.favorite_outline,
                  message: 'Your favorite songs will live here.',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/lists',
                builder: (context, state) => const ComingSoonScreen(
                  title: 'Lists',
                  icon: Icons.queue_music,
                  message: 'Create worship and meeting lists here soon.',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const ComingSoonScreen(
                  title: 'Settings',
                  icon: Icons.settings_outlined,
                  message: 'Reading and sync preferences are coming next.',
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
