import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';

import '../models/device_models.dart';
import '../services/backend_api.dart';
import '../services/env_service.dart';
import '../services/notification_registration_service.dart';

enum ConnectionPhase { idle, connecting, success, error }

class FeederProvider extends ChangeNotifier {
  FeederProvider() {
    _notificationRegistration = NotificationRegistrationService(
      onForegroundMessage: _handleNotification,
      onNotificationOpened: _handleNotification,
    );
  }

  static const _urlKey = 'backend_url';
  static const _tokenKey = 'backend_api_token';

  String backendUrl = EnvService.backendUrl;
  String apiToken = EnvService.backendApiToken;
  MasterStatus? master;
  CameraStatus? camera;
  ClassificationResult? classification;
  Uint8List? capturedImage;
  Uint8List? streamFrame;
  String streamStatus = 'Detenido';
  String? error;
  String? connectionMessage;
  ConnectionPhase connectionPhase = ConnectionPhase.idle;
  bool initialized = false;
  bool loading = false;
  bool cameraBusy = false;
  bool streamConnected = false;
  List<FeedingRound> rounds = const [];
  String? pendingNotificationMessage;
  int? pendingNotificationRoundId;

  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _masterStatusTimer;
  late final NotificationRegistrationService _notificationRegistration;

  BackendApi get _api => BackendApi(baseUrl: backendUrl, apiToken: apiToken);
  bool get cameraAccessAllowed =>
      master?.relayEnabled == true && master?.mode != 'manual_off';

  String get cameraAccessMessage {
    if (master == null) return 'Primero debes conectar el sistema.';
    if (master!.mode == 'manual_off') {
      return 'La cámara no está disponible en modo manual apagado.';
    }
    return 'La cámara solo está disponible durante una ronda automática activa. También puedes seleccionar Manual encendido.';
  }

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    backendUrl = preferences.getString(_urlKey) ?? EnvService.backendUrl;
    apiToken = preferences.getString(_tokenKey) ?? EnvService.backendApiToken;
    initialized = true;
    notifyListeners();
    if (apiToken.isNotEmpty) {
      unawaited(_notificationRegistration.register(_api));
      await refreshAll();
      _masterStatusTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => refreshMasterStatus(silent: true),
      );
    }
  }

  Future<void> saveSettings(String url, String token) async {
    backendUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    apiToken = token.trim();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_urlKey, backendUrl);
    await preferences.setString(_tokenKey, apiToken);
    error = null;
    connectionPhase = ConnectionPhase.connecting;
    connectionMessage = 'Conectando con el sistema...';
    notifyListeners();
    unawaited(_notificationRegistration.register(_api));
    await refreshAll();
  }

  Future<void> refreshAll() async {
    if (apiToken.isEmpty) {
      connectionPhase = ConnectionPhase.error;
      connectionMessage =
          'Agrega el token del servidor en Configuración para continuar.';
      notifyListeners();
      return;
    }
    loading = true;
    error = null;
    connectionPhase = ConnectionPhase.connecting;
    connectionMessage = 'Conectando con el sistema...';
    notifyListeners();
    try {
      final status = await _api.systemStatus();
      if (status.master == null) {
        throw const BackendException(
          'El servidor respondió, pero no pudo comunicarse con el ESP32 maestro.',
        );
      }
      master = status.master;
      camera = status.camera;
      if (cameraAccessAllowed && camera == null) {
        connectionPhase = ConnectionPhase.error;
        connectionMessage =
            'El maestro está listo, pero la cámara todavía no responde.';
      } else if (camera != null) {
        connectionPhase = ConnectionPhase.success;
        connectionMessage = '¡Conexión exitosa! Cámara y ventilador listos.';
      } else {
        connectionPhase = ConnectionPhase.success;
        connectionMessage =
            'Sistema conectado. La cámara está apagada según el modo actual.';
      }
    } catch (exception) {
      connectionPhase = ConnectionPhase.error;
      connectionMessage = exception.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
    await refreshRecentRounds();
  }

  Future<void> refreshRecentRounds() async {
    if (apiToken.isEmpty) return;
    try {
      rounds = await _api.recentRounds();
      notifyListeners();
    } catch (_) {
      // Device controls remain usable while an older backend is being upgraded.
    }
  }

  Future<void> setMode(String mode) async {
    loading = true;
    error = null;
    connectionPhase = ConnectionPhase.connecting;
    connectionMessage = mode == 'manual_on'
        ? 'Encendiendo la cámara y el ventilador...'
        : 'Aplicando el modo seleccionado...';
    notifyListeners();
    try {
      master = await _api.setMode(mode);
      if (mode == 'manual_off' || !cameraAccessAllowed) {
        await stopStream();
        camera = null;
      }
      if (mode == 'manual_on') {
        camera = await _waitForCamera();
        connectionMessage = '¡Listo! Cámara y ventilador encendidos.';
      } else if (mode == 'automatic') {
        connectionMessage = cameraAccessAllowed
            ? 'Modo automático activo. La ronda está en curso.'
            : 'Modo automático activo. Esperando la próxima ronda.';
      } else {
        connectionMessage = 'Cámara y ventilador apagados correctamente.';
      }
      connectionPhase = ConnectionPhase.success;
    } catch (exception) {
      error = exception.toString();
      connectionPhase = ConnectionPhase.error;
      connectionMessage = exception.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<CameraStatus> _waitForCamera() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        return await _api.cameraStatus();
      } catch (_) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    throw const BackendException(
      'La cámara no respondió después de encenderla. Revisa su alimentación y conexión Wi-Fi.',
    );
  }

  Future<bool> verifyCameraAccess() async {
    connectionPhase = ConnectionPhase.connecting;
    connectionMessage = 'Verificando si la cámara está disponible...';
    notifyListeners();
    final refreshed = await refreshMasterStatus();
    if (!refreshed) return false;
    if (!cameraAccessAllowed) {
      connectionPhase = ConnectionPhase.success;
      connectionMessage = cameraAccessMessage;
      notifyListeners();
      return false;
    }
    connectionPhase = ConnectionPhase.success;
    connectionMessage = 'Cámara disponible.';
    notifyListeners();
    return true;
  }

  Future<bool> refreshMasterStatus({bool silent = false}) async {
    if (apiToken.isEmpty) return false;
    try {
      master = await _api.masterStatus();
      if (!cameraAccessAllowed) {
        camera = null;
        if (streamConnected) await stopStream();
      }
      notifyListeners();
      return true;
    } catch (exception) {
      if (!silent) {
        connectionPhase = ConnectionPhase.error;
        connectionMessage = exception.toString();
        notifyListeners();
      }
      return false;
    }
  }

  Future<void> captureAndClassify() async {
    cameraBusy = true;
    error = null;
    connectionPhase = ConnectionPhase.connecting;
    connectionMessage = 'Capturando y clasificando la imagen...';
    notifyListeners();
    try {
      final capture = await _api.capture();
      capturedImage = capture.bytes;
      classification = await _api.classify();
      camera = await _api.cameraStatus();
      connectionPhase = ConnectionPhase.success;
      connectionMessage = 'Imagen clasificada correctamente.';
      try {
        final scheduled = await _api.scheduleDebugNotification(classification!);
        if (scheduled) {
          connectionMessage =
              'Imagen clasificada. La notificación de prueba llegará en unos 5 segundos.';
          await refreshRecentRounds();
        }
      } catch (_) {
        // Debug notifications are best-effort and never invalidate a classification.
      }
    } catch (exception) {
      error = exception is BackendException
          ? exception.message
          : 'No se pudo capturar y clasificar la imagen. Inténtalo nuevamente.';
      connectionPhase = ConnectionPhase.error;
      connectionMessage = error;
    } finally {
      cameraBusy = false;
      notifyListeners();
    }
  }

  Future<void> _handleNotification(RemoteMessage message) async {
    if (message.data['type'] != 'round_result') return;
    pendingNotificationRoundId = int.tryParse(
      message.data['round_id']?.toString() ?? '',
    );
    pendingNotificationMessage =
        message.notification?.body ?? 'Se completó una ronda de clasificación.';
    await refreshRecentRounds();
    notifyListeners();
  }

  ({String message, int? roundId})? takePendingNotification() {
    final message = pendingNotificationMessage;
    if (message == null) return null;
    final notification = (
      message: message,
      roundId: pendingNotificationRoundId,
    );
    pendingNotificationMessage = null;
    pendingNotificationRoundId = null;
    return notification;
  }

  Future<void> startStream() async {
    if (streamConnected) return;
    error = null;
    streamStatus = 'Conectando...';
    connectionPhase = ConnectionPhase.connecting;
    connectionMessage = 'Conectando con la cámara...';
    notifyListeners();
    try {
      final refreshed = await refreshMasterStatus();
      if (!refreshed) {
        throw const BackendException(
          'No se pudo verificar el estado del ESP32 maestro.',
        );
      }
      if (!cameraAccessAllowed) {
        throw BackendException(cameraAccessMessage);
      }
      final api = _api;
      _channel = IOWebSocketChannel.connect(
        api.debugStreamUri,
        headers: {'X-API-Key': apiToken},
        connectTimeout: const Duration(seconds: 10),
      );
      await _channel!.ready;
      streamConnected = true;
      streamStatus = 'Conectando...';
      _socketSubscription = _channel!.stream.listen(
        _handleSocketMessage,
        onError: (_) {
          error = 'Se perdió la conexión con la transmisión.';
          connectionPhase = ConnectionPhase.error;
          connectionMessage = error;
          _resetStream();
        },
        onDone: _resetStream,
      );
    } catch (exception) {
      error = exception is BackendException
          ? exception.message
          : 'No se pudo iniciar la transmisión. Revisa la conexión e inténtalo nuevamente.';
      connectionPhase = ConnectionPhase.error;
      connectionMessage = error;
      await stopStream();
    }
    notifyListeners();
  }

  void _handleSocketMessage(dynamic message) {
    if (message is List<int>) {
      if (message.length == 320 * 240 * 2) {
        streamFrame = Uint8List.fromList(message);
        streamStatus = 'En vivo';
        connectionPhase = ConnectionPhase.success;
        connectionMessage = 'Transmisión en vivo conectada.';
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
          error = _streamErrorMessage(data['error']?.toString());
          connectionPhase = ConnectionPhase.error;
          connectionMessage = error;
        case 'camera_status':
          streamStatus = switch (data['message']) {
            'READY' => 'Cámara lista',
            'STREAM_STARTED' => 'En vivo',
            'STREAM_STOPPED' => 'Detenido',
            _ => streamStatus,
          };
        case 'stream_config':
          streamStatus = 'Conectando...';
      }
    }
    notifyListeners();
  }

  String _streamErrorMessage(String? reason) => switch (reason) {
    'debug_mode_required' => cameraAccessMessage,
    'stream_start_timeout' =>
      'La cámara tardó demasiado en iniciar la transmisión.',
    _ => 'Ocurrió un problema durante la transmisión en vivo.',
  };

  Future<void> stopStream() async {
    await _socketSubscription?.cancel();
    await _channel?.sink.close();
    _resetStream();
  }

  void _resetStream() {
    _socketSubscription = null;
    _channel = null;
    streamConnected = false;
    streamStatus = 'Detenido';
    notifyListeners();
  }

  @override
  void dispose() {
    _masterStatusTimer?.cancel();
    _socketSubscription?.cancel();
    _channel?.sink.close();
    unawaited(_notificationRegistration.dispose());
    super.dispose();
  }
}
