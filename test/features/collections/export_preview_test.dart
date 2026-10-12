import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/shared/presentation/export_preview.dart';

void main() {
  testWidgets('share origin remains a small valid anchor on tablets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Rect? origin;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              origin = exportShareOrigin(context);
            },
            child: const Text('Anchor'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Anchor'));
    expect(origin?.size, const Size(1, 1));
    expect(origin!.center.dx, greaterThan(0));
    expect(origin!.center.dy, greaterThan(0));
  });

  testWidgets('cancelled preview never proceeds to share', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await confirmExportPreview(
                context,
                title: 'పాట',
                content: 'Photo omitted',
                image: true,
              );
            },
            child: const Text('Preview'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PDF supports multiple pages'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, false);
  });
}
