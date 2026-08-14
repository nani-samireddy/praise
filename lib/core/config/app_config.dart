abstract final class AppConfig {
  static const productionCatalogueManifestUrl =
      'https://nani-samireddy.github.io/praise-catalog/catalog/manifest.json';

  static const catalogueManifestUrl = String.fromEnvironment(
    'CATALOG_MANIFEST_URL',
    defaultValue: productionCatalogueManifestUrl,
  );

  static bool get isCatalogueSyncConfigured =>
      catalogueManifestUrl.trim().isNotEmpty;
}
