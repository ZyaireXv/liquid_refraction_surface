import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('example app renders liquid refraction demo controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LiquidRefractionExampleApp());
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('open-settings-button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('open-settings-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Surface Settings'), findsOneWidget);
    expect(find.text('Metalness'), findsOneWidget);
    expect(find.text('Auto Drops'), findsOneWidget);
    expect(find.text('Image'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('close-settings-button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('close-settings-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Surface Settings'), findsNothing);
  });
}
