import 'package:flutter_test/flutter_test.dart';

import 'package:lnlocate/main.dart';

void main() {
  testWidgets('App shows its title', (WidgetTester tester) async {
    await tester.pumpWidget(const LNLocateApp());

    expect(find.text('LNLocate'), findsOneWidget);
  });
}
