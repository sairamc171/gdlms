import 'package:flutter_test/flutter_test.dart';

// REPLAC THIS: Ensure the name after 'package:' matches your pubspec.yaml name
import 'package:lms_login_app/main.dart';

void main() {
  testWidgets('Counter infiltration test', (WidgetTester tester) async {
    // Now MyApp will be recognized
    await tester.pumpWidget(const MyApp());
  });
}
