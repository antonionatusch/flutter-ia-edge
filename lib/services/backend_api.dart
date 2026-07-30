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
    } catch (error) {
      throw BackendException('Connection failed: $error');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendException(_errorMessage(response));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _errorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return 'HTTP ${response.statusCode}: ${body['detail']}';
    } catch (_) {
      return 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
    }
  }

  Future<MasterStatus> masterStatus() async =>
      MasterStatus.fromJson(await _jsonRequest('GET', '/api/v1/master/status'));

  Future<CameraStatus> cameraStatus() async =>
      CameraStatus.fromJson(await _jsonRequest('GET', '/api/v1/camera/status'));

  Future<MasterStatus> setMode(String mode) async => MasterStatus.fromJson(
    await _jsonRequest('POST', '/api/v1/master/mode', body: {'mode': mode}),
  );

  Future<CaptureResult> capture() async {
    late http.Response response;
    try {
      response = await _client
          .get(_uri('/api/v1/camera/capture'), headers: _headers)
          .timeout(const Duration(seconds: 15));
    } catch (error) {
      throw BackendException('Capture failed: $error');
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
