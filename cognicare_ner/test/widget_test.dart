// Firebase-free smoke test. The app root now requires Firebase (auth/routing),
// so we exercise a pure design-system widget instead.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cognicare_ner/core/widgets/big_button.dart';

void main() {
  testWidgets('BigButton shows its label and responds to a tap',
      (WidgetTester tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BigButton(label: 'Play', onTap: () => tapped = true),
        ),
      ),
    );

    expect(find.text('Play'), findsOneWidget);

    await tester.tap(find.text('Play'));
    expect(tapped, isTrue);
  });
}
