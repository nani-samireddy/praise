abstract final class AppConfig {
  static const productionCatalogueManifestUrl =
      'https://nani-samireddy.github.io/praise-catalog/catalog/manifest.json';

  static const catalogueManifestUrl = String.fromEnvironment(
    'CATALOG_MANIFEST_URL',
    defaultValue: productionCatalogueManifestUrl,
  );

  static const productionFeedbackApiUrl =
      'https://praise-support-api.onrender.com/v1/issues';

  static const feedbackApiUrl = String.fromEnvironment(
    'FEEDBACK_API_URL',
    defaultValue: productionFeedbackApiUrl,
  );

  static bool get isCatalogueSyncConfigured =>
      catalogueManifestUrl.trim().isNotEmpty;

  static bool get isFeedbackConfigured => feedbackApiUrl.trim().isNotEmpty;
}
