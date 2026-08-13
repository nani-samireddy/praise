import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme/app_theme.dart';
import '../features/settings/presentation/settings_providers.dart';

class PraiseApp extends ConsumerWidget {
  const PraiseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Praise',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
