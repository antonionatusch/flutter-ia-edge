import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_ia_edge/main.dart';

void main() {
  testWidgets('shows the dashboard and primary navigation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(
      envString: 'BACKEND_URL=http://localhost:7890\nBACKEND_API_TOKEN=test',
    );

    await tester.pumpWidget(const FeederApp());
    await tester.pumpAndSettle();

    expect(find.text('Pet feeder'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
