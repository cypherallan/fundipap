import 'package:flutter_test/flutter_test.dart';
import 'package:fundipap/app.dart';

void main() {
  testWidgets('Fundi Pap loads', (WidgetTester tester) async {
    await tester.pumpWidget(const FundiPapApp());

    expect(find.text('Fundi Pap - Ogango'), findsOneWidget);
  });
}
