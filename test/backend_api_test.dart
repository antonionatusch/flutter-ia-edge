import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_ia_edge/models/device_models.dart';
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

  test('registra el token FCM con una instalación estable', () async {
    late http.Request capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({
          'installation_id': 'installation-123',
          'platform': 'android',
          'device_name': null,
          'enabled': true,
          'created_at': '2026-07-30 19:00:00',
          'updated_at': '2026-07-30 19:00:00',
        }),
        200,
      );
    });
    final api = BackendApi(
      baseUrl: 'http://localhost:7890',
      apiToken: 'test',
      client: client,
    );

    await api.registerNotificationDevice(
      installationId: 'installation-123',
      fcmToken: 'fcm-token-value',
    );

    expect(capturedRequest.url.path, '/api/v1/notifications/devices');
    expect(capturedRequest.headers['X-API-Key'], 'test');
    expect(jsonDecode(capturedRequest.body), {
      'installation_id': 'installation-123',
      'fcm_token': 'fcm-token-value',
      'platform': 'android',
    });
  });

  test('consulta rondas recientes', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'items': [
            {
              'id': 4,
              'scheduled_at': '2026-07-31T08:00:00-04:00',
              'source': 'automatic',
              'status': 'completed',
              'result': 'food_available',
              'confidence': 0.91,
              'sample_count': 5,
              'valid_sample_count': 5,
              'error': null,
            },
          ],
        }),
        200,
      ),
    );
    final api = BackendApi(
      baseUrl: 'http://localhost:7890',
      apiToken: 'test',
      client: client,
    );

    final rounds = await api.recentRounds();

    expect(rounds.single.id, 4);
    expect(rounds.single.result, 'food_available');
    expect(rounds.single.validSampleCount, 5);
  });

  test('programa notificación debug con la clasificación', () async {
    late http.Request capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({'scheduled': true, 'round_id': 8, 'delay_seconds': 5}),
        200,
      );
    });
    final api = BackendApi(
      baseUrl: 'http://localhost:7890',
      apiToken: 'test',
      client: client,
    );

    final scheduled = await api.scheduleDebugNotification(
      const ClassificationResult(
        status: 'classified',
        predictedClass: 'empty',
        confidence: 0.88,
        scores: {},
        frameId: 12,
      ),
    );

    expect(scheduled, isTrue);
    expect(capturedRequest.url.path, '/api/v1/notifications/debug');
    expect(jsonDecode(capturedRequest.body), {
      'predicted_class': 'empty',
      'confidence': 0.88,
      'frame_id': 12,
    });
  });
}
