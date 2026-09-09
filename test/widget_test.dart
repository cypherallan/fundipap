import 'package:flutter_test/flutter_test.dart';
import 'package:fundipap/main.dart';

void main() {
  testWidgets('FUNDIPAP v1.0 loads', (WidgetTester tester) async {
    // Build our FUNDIPAP app
    await tester.pumpWidget(const FundipapApp());

    // Check that Customer screen text exists
    expect(find.text('FUNDIPAP'), findsOneWidget);
    expect(find.textContaining('OGANGO'), findsOneWidget);
  });
}
