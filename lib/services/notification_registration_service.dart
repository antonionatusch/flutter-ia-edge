import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_api.dart';

class NotificationRegistrationService {
  NotificationRegistrationService({
    FirebaseMessaging? messaging,
    Logger? logger,
  }) : _providedMessaging = messaging,
       _logger = logger ?? Logger();

  static const _installationIdKey = 'notification_installation_id';

  final FirebaseMessaging? _providedMessaging;
  final Logger _logger;
  BackendApi? _api;
  StreamSubscription<String>? _tokenSubscription;

  FirebaseMessaging get _messaging =>
      _providedMessaging ?? FirebaseMessaging.instance;

  Future<void> register(BackendApi api) async {
    _api = api;
    try {
      final permission = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        _logger.w('El usuario rechazó las notificaciones.');
        return;
      }

      final token = await _messaging.getToken();
      if (token == null) {
        _logger.w('Firebase no entregó un token FCM.');
        return;
      }

      await _registerToken(token);
      _tokenSubscription ??= _messaging.onTokenRefresh.listen(
        (token) => unawaited(_registerRefreshedToken(token)),
      );
    } catch (error, stackTrace) {
      _logger.e(
        'No se pudo registrar este dispositivo para notificaciones.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _registerRefreshedToken(String token) async {
    try {
      await _registerToken(token);
    } catch (error, stackTrace) {
      _logger.e(
        'No se pudo renovar el token FCM.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _registerToken(String token) async {
    final api = _api;
    if (api == null) return;

    final preferences = await SharedPreferences.getInstance();
    var installationId = preferences.getString(_installationIdKey);
    if (installationId == null) {
      installationId = _generateInstallationId();
      await preferences.setString(_installationIdKey, installationId);
    }

    await api.registerNotificationDevice(
      installationId: installationId,
      fcmToken: token,
    );
    _logger.i('Dispositivo registrado para notificaciones FCM.');
  }

  String _generateInstallationId() {
    final bytes = List<int>.generate(24, (_) => Random.secure().nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
  }
}
