import 'package:flutter_test/flutter_test.dart';

import 'package:pfe/main.dart';

void main() {
  testWidgets('App builds without session (splash)', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(hasSession: false));
    await tester.pump();

    expect(find.text('LANCY'), findsOneWidget);
  });
}
