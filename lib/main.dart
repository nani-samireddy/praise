import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/database/app_database.dart';
import 'core/database/seed_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();
  await SeedService(database).seedIfNeeded();

  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: const PraiseApp(),
    ),
  );
}
