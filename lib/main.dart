
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'providers/feeder_provider.dart';
import 'screens/home_shell.dart';

final _log = Logger();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Firebase.initializeApp();
  final token = await FirebaseMessaging.instance.getToken();
  _log.i('FCM Token: $token');
  runApp(const FeederApp());
}

class FeederApp extends StatelessWidget {
  const FeederApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FeederProvider()..initialize(),
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
