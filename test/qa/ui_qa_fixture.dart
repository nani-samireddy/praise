import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/features/favorites/presentation/favorite_providers.dart';
import 'package:praise/features/settings/data/telugu_font.dart';
import 'package:praise/features/settings/presentation/settings_providers.dart';

const qaTeluguTitle = 'యేసయ్యా నీ ప్రేమను నిత్యము స్తుతించెదను ఆరాధించెదను';
const qaEnglishTitle = 'A very long worship song title for the Sunday service';
const qaViewports = <String, Size>{
  'small phone': Size(320, 568),
  'landscape': Size(568, 320),
  'tablet': Size(1024, 768),
};

/// Deterministic offline fixture: no SQLite, network, plugins or user data.
Future<void> pumpQaSurface(
  WidgetTester tester, {
  required Widget child,
  required Size size,
  required Brightness brightness,
  double textScale = 2,
  bool favorite = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        teluguFontProvider.overrideWith(
          (ref) => Stream.value(TeluguFont.system),
        ),
        isFavoriteProvider('qa-song')
            .overrideWith((ref) => Stream.value(favorite)),
      ],
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          brightness: brightness,
          fontFamily: 'NotoSansTelugu',
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(body: SafeArea(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
