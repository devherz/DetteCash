import 'package:flutter_test/flutter_test.dart';
import 'package:dettecash/main.dart';

void main() {
  testWidgets('App launch smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that it shows the loading text.
    expect(find.text('Chargement de DetteCash...'), findsOneWidget);
  });
}
