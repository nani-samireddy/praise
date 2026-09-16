import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';

import 'app/app.dart';
import 'core/database/app_database.dart';
import 'core/database/seed_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();
  final hadSeed =
      await (database.select(database.appMetadata)
            ..where((row) => row.key.equals('bundled_song_catalogue_version')))
          .getSingleOrNull();
  await SeedService(database).seedIfNeeded();
  if (hadSeed == null) {
    await database
        .into(database.appMetadata)
        .insert(
          AppMetadataCompanion.insert(
            key: 'setting_onboarding_complete',
            value: 'false',
            updatedAt: DateTime.now().toUtc(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: const PraiseApp(),
    ),
  );
}
