import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/features/collections/presentation/collection_dialogs.dart';

void main() {
  testWidgets('saves a trimmed list name without lifecycle exceptions', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      _DialogTestApp(onResult: (value) => result = value),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '  Sunday Worship  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, 'Sunday Worship');
    expect(tester.takeException(), isNull);
  });

  testWidgets('submits a list name from the keyboard', (tester) async {
    String? result;
    await tester.pumpWidget(
      _DialogTestApp(onResult: (value) => result = value),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Prayer');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(result, 'Prayer');
    expect(tester.takeException(), isNull);
  });
}

class _DialogTestApp extends StatelessWidget {
  const _DialogTestApp({required this.onResult});

  final ValueChanged<String?> onResult;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              onResult(
                await showCollectionNameDialog(context, title: 'New list'),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
  }
}
