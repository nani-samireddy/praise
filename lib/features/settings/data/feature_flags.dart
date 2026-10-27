import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

enum PrimaryRole {
  singer,
  musician,
  worshipLeader;

  String get label => switch (this) {
    singer => 'Singer',
    musician => 'Musician',
    worshipLeader => 'Worship leader',
  };
}

enum FeatureKey {
  practiceVideos,
  metronome,
  repeatExpansion,
  chordDisplay,
  chordTranspose,
  capoShapes,
  harmony,
  adaptiveSongControls,
}

class FeatureSettingsStore {
  FeatureSettingsStore(this.database);
  final AppDatabase database;
  static const onboardingKey = 'setting_onboarding_complete';
  static const roleKey = 'setting_primary_role';
  String key(FeatureKey feature) => 'feature_${feature.name}_enabled';
  Stream<String?> watch(String key) => (database.select(
    database.appMetadata,
  )..where((r) => r.key.equals(key))).watchSingleOrNull().map((r) => r?.value);
  Future<void> set(String key, String value) async => database
      .into(database.appMetadata)
      .insert(
        AppMetadataCompanion.insert(
          key: key,
          value: value,
          updatedAt: DateTime.now().toUtc(),
        ),
        mode: InsertMode.insertOrReplace,
      );
  Stream<bool> watchOnboarding() =>
      watch(onboardingKey).map((v) => v == null ? true : v == 'true');
  Stream<PrimaryRole?> watchRole() => watch(roleKey).map((v) {
    for (final role in PrimaryRole.values) {
      if (role.name == v) return role;
    }
    return null;
  });
  // All tools are available for every role. Legacy saved switches are ignored.
  Stream<bool> watchFeature(FeatureKey feature) => Stream.value(true);

  Future<void> complete(PrimaryRole role) => database.transaction(() async {
    await set(roleKey, role.name);
    await set(onboardingKey, 'true');
  });

  Future<void> reset() => set(onboardingKey, 'false');
}
