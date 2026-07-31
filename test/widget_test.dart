import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_ia_edge/main.dart';
import 'package:flutter_ia_edge/services/local_notification_service.dart';

void main() {
  testWidgets('muestra el panel y la navegación principal', (tester) async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(
      envString: 'BACKEND_URL=http://localhost:7890\nBACKEND_API_TOKEN=',
    );

    final localNotifications = LocalNotificationService();
    await tester.pumpWidget(FeederApp(localNotifications: localNotifications));
    await tester.pumpAndSettle();

    expect(find.text('Comedero inteligente'), findsOneWidget);
    expect(find.text('Estado'), findsOneWidget);
    expect(find.text('Cámara'), findsOneWidget);
    expect(find.text('Configuración'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('Rondas recientes'), findsOneWidget);
    expect(find.text('Todavía no hay rondas registradas.'), findsOneWidget);
  });
}
