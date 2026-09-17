import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

enum PrimaryRole { singer, musician, worshipLeader }

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

class FeatureDefinition {
  const FeatureDefinition(this.key, this.label, this.description);
  final FeatureKey key;
  final String label;
  final String description;
}

const featureDefinitions = <FeatureDefinition>[
  FeatureDefinition(
    FeatureKey.practiceVideos,
    'Practice videos',
    'Play linked YouTube recordings.',
  ),
  FeatureDefinition(
    FeatureKey.metronome,
    'Metronome',
    'Keep a steady beat while you practice.',
  ),
  FeatureDefinition(
    FeatureKey.repeatExpansion,
    'Show full lyrics',
    'Expand repeated sections.',
  ),
  FeatureDefinition(
    FeatureKey.chordDisplay,
    'Show chords',
    'Show chord names above the lyrics.',
  ),
  FeatureDefinition(
    FeatureKey.chordTranspose,
    'Transpose chords',
    'Change the chord key while reading.',
  ),
  FeatureDefinition(
    FeatureKey.capoShapes,
    'Guitar shapes',
    'Show playable shapes for songs with a capo.',
  ),
  FeatureDefinition(
    FeatureKey.harmony,
    'Harmony parts',
    'Practice vocal harmony lines.',
  ),
  FeatureDefinition(
    FeatureKey.adaptiveSongControls,
    'Adaptive song controls',
    'Move song controls to the easier side while you hold your phone.',
  ),
];

Set<FeatureKey> roleDefaults(PrimaryRole role) {
  final enabled = <FeatureKey>{
    FeatureKey.practiceVideos,
    FeatureKey.repeatExpansion,
    FeatureKey.harmony,
  };
  if (role != PrimaryRole.singer) {
    enabled.addAll({
      FeatureKey.chordDisplay,
      FeatureKey.chordTranspose,
      FeatureKey.metronome,
      FeatureKey.capoShapes,
    });
  }
  return enabled;
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
  Stream<bool> watchFeature(FeatureKey feature) => watch(key(feature)).map(
    (v) => v == null ? feature != FeatureKey.adaptiveSongControls : v == 'true',
  );
  Future<void> complete(PrimaryRole role) async {
    await set(roleKey, role.name);
    await set(onboardingKey, 'true');
    for (final f in featureDefinitions) {
      await set(
        key(f.key),
        roleDefaults(role).contains(f.key) ? 'true' : 'false',
      );
    }
  }

  Future<void> reset() => set(onboardingKey, 'false');
}
