import 'package:flutter_test/flutter_test.dart';

import 'package:meshlix_app/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MeshlixApp());
    await tester.pump();
    expect(find.text('MESHLIX'), findsOneWidget);
  });
}
