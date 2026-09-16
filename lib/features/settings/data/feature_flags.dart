import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

enum PrimaryRole { singer, musician, worshipLeader }

enum FeatureKey {
  transliteration,
  practiceVideos,
  metronome,
  repeatExpansion,
  chordDisplay,
  chordTranspose,
  capoShapes,
  stageMode,
  autoScroll,
  vocalRange,
  startingPitch,
  harmony,
  arrangements,
  rehearsal,
  teams,
  liveWorship,
  cloudBackup,
  lumina,
  catalogueSync,
}

class FeatureDefinition {
  const FeatureDefinition(
    this.key,
    this.label,
    this.description, {
    this.available = true,
  });
  final FeatureKey key;
  final String label;
  final String description;
  final bool available;
}

const featureDefinitions = <FeatureDefinition>[
  FeatureDefinition(
    FeatureKey.transliteration,
    'English transliteration',
    'Show Telugu in Latin script.',
  ),
  FeatureDefinition(
    FeatureKey.practiceVideos,
    'Practice videos',
    'Play linked YouTube recordings.',
  ),
  FeatureDefinition(
    FeatureKey.metronome,
    'Metronome',
    'Keep a steady practice tempo.',
  ),
  FeatureDefinition(
    FeatureKey.repeatExpansion,
    'Repeat expansion',
    'Expand repeated lyric blocks.',
  ),
  FeatureDefinition(
    FeatureKey.chordDisplay,
    'Chord display',
    'Show chords with lyrics.',
  ),
  FeatureDefinition(
    FeatureKey.catalogueSync,
    'Catalogue sync',
    'Refresh published songs.',
  ),
  FeatureDefinition(
    FeatureKey.chordTranspose,
    'Chord transposition',
    'Change the sounding key.',
    available: false,
  ),
  FeatureDefinition(
    FeatureKey.capoShapes,
    'Capo and guitar shapes',
    'Show playable guitar shapes.',
    available: false,
  ),
  FeatureDefinition(
    FeatureKey.stageMode,
    'Stage mode',
    'Distraction-free live display.',
    available: false,
  ),
  FeatureDefinition(
    FeatureKey.autoScroll,
    'Auto-scroll',
    'Scroll lyrics while performing.',
    available: false,
  ),
  FeatureDefinition(
    FeatureKey.vocalRange,
    'Vocal range tools',
    'Track range and suggested keys.',
    available: false,
  ),
  FeatureDefinition(
    FeatureKey.startingPitch,
    'Starting pitch',
    'Play a reference starting note.',
    available: false,
  ),
  FeatureDefinition(
    FeatureKey.harmony,
    'Harmony parts',
    'Practice vocal harmony lines.',
    available: false,
  ),
  FeatureDefinition(
    FeatureKey.arrangements,
    'Arrangement builder',
    'Create service-specific song orders.',
    available: false,
  ),
  FeatureDefinition(
    FeatureKey.rehearsal,
    'Rehearsal loops and count-in',
    'Practice selected sections.',
    available: false,
  ),
  FeatureDefinition(
    FeatureKey.teams,
    'Worship teams',
    'Coordinate musicians and services.',
    available: false,
  ),
  FeatureDefinition(
    FeatureKey.liveWorship,
    'Live worship control',
    'Synchronize the current section.',
    available: false,
  ),
  FeatureDefinition(
    FeatureKey.cloudBackup,
    'Cloud backup',
    'Back up personal data.',
    available: false,
  ),
  FeatureDefinition(
    FeatureKey.lumina,
    'Lumina integration',
    'Present lyrics to Lumina.',
    available: false,
  ),
];

Set<FeatureKey> roleDefaults(PrimaryRole role) {
  final enabled = <FeatureKey>{
    FeatureKey.transliteration,
    FeatureKey.practiceVideos,
    FeatureKey.repeatExpansion,
  };
  if (role != PrimaryRole.singer) {
    enabled.addAll({FeatureKey.chordDisplay, FeatureKey.metronome});
  }
  if (role == PrimaryRole.worshipLeader) {
    enabled.add(FeatureKey.catalogueSync);
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
  Stream<bool> watchFeature(FeatureKey feature) =>
      watch(key(feature)).map((v) => v == null ? true : v == 'true');
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
