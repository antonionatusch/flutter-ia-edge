import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_ia_edge/main.dart';

void main() {
  testWidgets('muestra el panel y la navegación principal', (tester) async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(
      envString: 'BACKEND_URL=http://localhost:7890\nBACKEND_API_TOKEN=',
    );

    await tester.pumpWidget(const FeederApp());
    await tester.pumpAndSettle();

    expect(find.text('Comedero inteligente'), findsOneWidget);
    expect(find.text('Estado'), findsOneWidget);
    expect(find.text('Cámara'), findsOneWidget);
    expect(find.text('Configuración'), findsOneWidget);
  });
}
