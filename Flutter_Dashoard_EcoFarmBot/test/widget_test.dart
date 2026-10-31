import 'package:flutter_test/flutter_test.dart';
import 'package:ecofarmbot_app/main.dart';

void main() {
  testWidgets('SmartAgriRoverApp loads and displays title', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SmartAgriRoverApp());

    // Verify app title appears
    expect(find.text('SMART AGRI-ROVER'), findsOneWidget);
    expect(find.text('DEPLOY SOIL SENSOR'), findsOneWidget);
  });
}
