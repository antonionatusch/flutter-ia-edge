import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvService {
  static String get backendUrl =>
      dotenv.env['BACKEND_URL'] ?? 'http://localhost:7890';

  static String get backendApiToken => dotenv.env['BACKEND_API_TOKEN'] ?? '';
}
