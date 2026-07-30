import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';

import '../models/device_models.dart';
import '../services/backend_api.dart';

class FeederProvider extends ChangeNotifier {
  static const _urlKey = 'backend_url';
  static const _tokenKey = 'backend_api_token';
  static const _defaultUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://100.72.169.109:7890',
  );
  static const _defaultToken = String.fromEnvironment('BACKEND_API_TOKEN');

  String backendUrl = _defaultUrl;
  String apiToken = _defaultToken;
  MasterStatus? master;
  CameraStatus? camera;
  ClassificationResult? classification;
  Uint8List? capturedImage;
  Uint8List? streamFrame;
  String streamStatus = 'Stopped';
  String? error;
  bool initialized = false;
  bool loading = false;
  bool cameraBusy = false;
  bool streamConnected = false;

  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSubscription;

  BackendApi get _api => BackendApi(baseUrl: backendUrl, apiToken: apiToken);

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    backendUrl = preferences.getString(_urlKey) ?? _defaultUrl;
    apiToken = preferences.getString(_tokenKey) ?? _defaultToken;
    initialized = true;
    notifyListeners();
    if (apiToken.isNotEmpty) await refreshAll();
  }

  Future<void> saveSettings(String url, String token) async {
    backendUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    apiToken = token.trim();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_urlKey, backendUrl);
    await preferences.setString(_tokenKey, apiToken);
    error = null;
    notifyListeners();
    await refreshAll();
  }

  Future<void> refreshAll() async {
    if (apiToken.isEmpty) {
      error = 'Add the backend API token in Settings.';
      notifyListeners();
      return;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.masterStatus(),
        _api.cameraStatus(),
      ]);
      master = results[0] as MasterStatus;
      camera = results[1] as CameraStatus;
    } catch (exception) {
      error = exception.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> setMode(String mode) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      master = await _api.setMode(mode);
      if (mode == 'manual_off') await stopStream();
    } catch (exception) {
      error = exception.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> captureAndClassify() async {
    cameraBusy = true;
    error = null;
    notifyListeners();
    try {
      final capture = await _api.capture();
      capturedImage = capture.bytes;
      classification = await _api.classify();
      camera = await _api.cameraStatus();
    } catch (exception) {
      error = exception.toString();
    } finally {
      cameraBusy = false;
      notifyListeners();
    }
  }

  Future<void> startStream() async {
    if (streamConnected) return;
    error = null;
    streamStatus = 'Powering camera...';
    notifyListeners();
    try {
      if (master?.mode != 'manual_on' || master?.relayEnabled != true) {
        master = await _api.setMode('manual_on');
      }
      final api = _api;
      _channel = IOWebSocketChannel.connect(
        api.debugStreamUri,
        headers: {'X-API-Key': apiToken},
        connectTimeout: const Duration(seconds: 10),
      );
      await _channel!.ready;
      streamConnected = true;
      streamStatus = 'Connecting...';
      _socketSubscription = _channel!.stream.listen(
        _handleSocketMessage,
        onError: (Object socketError) {
          error = 'Stream failed: $socketError';
          _resetStream();
        },
        onDone: _resetStream,
      );
    } catch (exception) {
      error = 'Stream failed: $exception';
      await stopStream();
    }
    notifyListeners();
  }

  void _handleSocketMessage(dynamic message) {
    if (message is List<int>) {
      if (message.length == 320 * 240 * 2) {
        streamFrame = Uint8List.fromList(message);
        streamStatus = 'Live';
      }
    } else if (message is String) {
      final data = jsonDecode(message) as Map<String, dynamic>;
      switch (data['type']) {
        case 'classification':
          classification = ClassificationResult.fromJson(
            data['data'] as Map<String, dynamic>,
          );
        case 'stream_error':
        case 'classification_error':
          error = data['error']?.toString() ?? 'Stream error';
        case 'camera_status':
          streamStatus = data['message']?.toString() ?? streamStatus;
        case 'stream_config':
          streamStatus = data['status']?.toString() ?? 'Connecting...';
      }
    }
    notifyListeners();
  }

  Future<void> stopStream() async {
    await _socketSubscription?.cancel();
    await _channel?.sink.close();
    _resetStream();
  }

  void _resetStream() {
    _socketSubscription = null;
    _channel = null;
    streamConnected = false;
    streamStatus = 'Stopped';
    notifyListeners();
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
