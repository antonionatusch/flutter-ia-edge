import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/device_models.dart';

class BackendException implements Exception {
  const BackendException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackendApi {
  BackendApi({
    required this.baseUrl,
    required this.apiToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String apiToken;
  final http.Client _client;

  Map<String, String> get _headers => {
    'X-API-Key': apiToken,
    'Content-Type': 'application/json',
  };

  Uri _uri(String path) =>
      Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');

  Future<Map<String, dynamic>> _jsonRequest(
    String method,
    String path, {
    Object? body,
  }) async {
    late http.Response response;
    try {
      response = switch (method) {
        'GET' =>
          await _client
              .get(_uri(path), headers: _headers)
              .timeout(const Duration(seconds: 10)),
        'POST' =>
          await _client
              .post(
                _uri(path),
                headers: _headers,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(const Duration(seconds: 15)),
        _ => throw ArgumentError('Unsupported method: $method'),
      };
    } catch (_) {
      throw const BackendException(
        'No se pudo conectar con el servidor. Revisa la red e inténtalo nuevamente.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendException(_errorMessage(response));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _errorMessage(http.Response response) {
    String? reason;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = body['detail'];
      reason = detail is Map<String, dynamic>
          ? detail['reason']?.toString()
          : detail?.toString();
    } catch (_) {}

    return switch (reason) {
      'invalid_api_key' =>
        'El token de acceso no es válido. Revísalo en Configuración.',
      'timeout' =>
        'El dispositivo tardó demasiado en responder. Inténtalo nuevamente.',
      'debug_mode_required' =>
        'La cámara solo está disponible durante una ronda activa o en modo manual encendido.',
      'camera_not_ready' => 'La cámara todavía se está iniciando.',
      'device_busy' => 'La cámara está ocupada. Inténtalo en unos segundos.',
      'no_cached_frame' => 'Primero debes capturar una imagen.',
      'capture_failed' => 'No se pudo capturar la imagen.',
      'model_not_ready' => 'El modelo de clasificación no está disponible.',
      'All connection attempts failed' =>
        'No se pudo conectar con el dispositivo en la red local.',
      _ when response.statusCode == 401 =>
        'El token de acceso no es válido. Revísalo en Configuración.',
      _ when response.statusCode == 502 || response.statusCode == 504 =>
        'El servidor está activo, pero no pudo comunicarse con el dispositivo.',
      _ => 'Ocurrió un problema al comunicarse con el servidor.',
    };
  }

  Future<MasterStatus> masterStatus() async =>
      MasterStatus.fromJson(await _jsonRequest('GET', '/api/v1/master/status'));

  Future<CameraStatus> cameraStatus() async =>
      CameraStatus.fromJson(await _jsonRequest('GET', '/api/v1/camera/status'));

  Future<SystemStatus> systemStatus() async =>
      SystemStatus.fromJson(await _jsonRequest('GET', '/api/v1/system/status'));

  Future<MasterStatus> setMode(String mode) async => MasterStatus.fromJson(
    await _jsonRequest('POST', '/api/v1/master/mode', body: {'mode': mode}),
  );

  Future<CaptureResult> capture() async {
    late http.Response response;
    try {
      response = await _client
          .get(_uri('/api/v1/camera/capture'), headers: _headers)
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const BackendException(
        'No se pudo capturar la imagen. Revisa la conexión e inténtalo nuevamente.',
      );
    }
    if (response.statusCode != 200) {
      throw BackendException(_errorMessage(response));
    }
    return CaptureResult(response.bodyBytes, response.headers['x-frame-id']);
  }

  Future<ClassificationResult> classify() async =>
      ClassificationResult.fromJson(
        await _jsonRequest('POST', '/api/v1/camera/classify'),
      );

  Uri get debugStreamUri {
    final httpUri = _uri('/api/v1/camera/debug-stream');
    return httpUri.replace(scheme: httpUri.scheme == 'https' ? 'wss' : 'ws');
  }
}
