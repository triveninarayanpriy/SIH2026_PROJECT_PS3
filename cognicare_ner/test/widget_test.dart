// Basic smoke test for the CogniCare NER placeholder app.

import 'package:flutter_test/flutter_test.dart';

import 'package:cognicare_ner/app.dart';

void main() {
  testWidgets('renders the role name on the placeholder screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CogniCareApp(role: 'patient'));

    expect(find.text('patient'), findsOneWidget);
    expect(find.text('CogniCare NER'), findsOneWidget);
  });
}
