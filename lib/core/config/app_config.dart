abstract final class AppConfig {
  static const catalogueManifestUrl = String.fromEnvironment(
    'CATALOG_MANIFEST_URL',
    defaultValue: '',
  );

  static bool get isCatalogueSyncConfigured =>
      catalogueManifestUrl.trim().isNotEmpty;
}
