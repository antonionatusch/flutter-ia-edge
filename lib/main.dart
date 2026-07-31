import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'providers/feeder_provider.dart';
import 'screens/home_shell.dart';
import 'services/local_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Firebase.initializeApp();

  final localNotifications = LocalNotificationService();
  await localNotifications.initialize(onSelectNotification: (_) {});

  runApp(FeederApp(localNotifications: localNotifications));
}

class FeederApp extends StatelessWidget {
  const FeederApp({super.key, required this.localNotifications});

  final LocalNotificationService localNotifications;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          FeederProvider(localNotifications: localNotifications)..initialize(),
      child: MaterialApp(
        title: 'Comedero IA Edge',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF236A5B),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF4F6F2),
          cardTheme: const CardThemeData(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(18)),
              side: BorderSide(color: Color(0xFFDCE4DE)),
            ),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
          ),
          useMaterial3: true,
        ),
        home: const HomeShell(),
      ),
    );
  }
}
