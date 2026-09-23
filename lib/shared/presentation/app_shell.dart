import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  static const _tabCount = 4;

  const AppShell({
    super.key,
    required this.navigationShell,
    this.showBottomNavigationBar = true,
  });

  final StatefulNavigationShell navigationShell;
  final bool showBottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final body = showBottomNavigationBar
        ? GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity.abs() < 300) return;

              final currentIndex = navigationShell.currentIndex;
              final direction = velocity < 0 ? 1 : -1;
              final targetIndex = currentIndex + direction;
              if (targetIndex < 0 || targetIndex >= _tabCount) return;

              navigationShell.goBranch(
                targetIndex,
                initialLocation: targetIndex == currentIndex,
              );
            },
            child: navigationShell,
          )
        : navigationShell;

    return Scaffold(
      body: body,
      bottomNavigationBar: showBottomNavigationBar
          ? NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) {
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.library_music_outlined),
                  selectedIcon: Icon(Icons.library_music),
                  label: 'Songs',
                ),
                NavigationDestination(
                  icon: Icon(Icons.favorite_outline),
                  selectedIcon: Icon(Icons.favorite),
                  label: 'Favorites',
                ),
                NavigationDestination(
                  icon: Icon(Icons.queue_music_outlined),
                  selectedIcon: Icon(Icons.queue_music),
                  label: 'Lists',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            )
          : null,
    );
  }
}
