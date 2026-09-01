import 'package:flutter_test/flutter_test.dart';
import 'package:praise/core/config/app_config.dart';

void main() {
  test('uses the production catalogue by default', () {
    expect(
      AppConfig.catalogueManifestUrl,
      'https://nani-samireddy.github.io/praise-catalog/catalog/manifest.json',
    );
    expect(AppConfig.isCatalogueSyncConfigured, isTrue);
    expect(
      AppConfig.feedbackApiUrl,
      'https://praise-support.nanisamireddy05.workers.dev/v1/issues',
    );
    expect(AppConfig.isFeedbackConfigured, isTrue);
  });
}
