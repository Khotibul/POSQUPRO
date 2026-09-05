import 'package:flutter_test/flutter_test.dart';
import 'package:posqupro_mobile/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PosquproApp());
    await tester.pumpAndSettle();
  });
}
