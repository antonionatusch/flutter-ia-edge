import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_ia_edge/services/backend_api.dart';

void main() {
  test('convierte un error del backend en un mensaje claro', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'detail': {
            'device': 'camera',
            'reason': 'All connection attempts failed',
          },
        }),
        502,
      ),
    );
    final api = BackendApi(
      baseUrl: 'http://localhost:7890',
      apiToken: 'test',
      client: client,
    );

    await expectLater(
      api.cameraStatus(),
      throwsA(
        isA<BackendException>().having(
          (error) => error.message,
          'mensaje',
          'No se pudo conectar con el dispositivo en la red local.',
        ),
      ),
    );
  });
}
