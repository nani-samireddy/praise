import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/feature_flags.dart';

final featureSettingsStoreProvider = Provider(
  (ref) => FeatureSettingsStore(ref.watch(databaseProvider)),
);
final onboardingCompleteProvider = StreamProvider<bool>(
  (ref) => ref.watch(featureSettingsStoreProvider).watchOnboarding(),
);
final primaryRoleProvider = StreamProvider<PrimaryRole?>(
  (ref) => ref.watch(featureSettingsStoreProvider).watchRole(),
);
final featureEnabledProvider = StreamProvider.family<bool, FeatureKey>(
  (ref, key) => ref.watch(featureSettingsStoreProvider).watchFeature(key),
);
