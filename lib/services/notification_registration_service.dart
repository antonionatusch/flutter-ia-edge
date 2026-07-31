import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_api.dart';
import 'local_notification_service.dart';

class NotificationRegistrationService {
  NotificationRegistrationService({
    FirebaseMessaging? messaging,
    Logger? logger,
    LocalNotificationService? localNotifications,
    this.onForegroundMessage,
    this.onNotificationOpened,
  }) : _providedMessaging = messaging,
       _logger = logger ?? Logger(),
       _localNotifications = localNotifications;
  static const _installationIdKey = 'notification_installation_id';

  final FirebaseMessaging? _providedMessaging;
  final Logger _logger;
  final LocalNotificationService? _localNotifications;
  final Future<void> Function(RemoteMessage message)? onForegroundMessage;
  final Future<void> Function(RemoteMessage message)? onNotificationOpened;
  BackendApi? _api;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  bool _initialMessageHandled = false;

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

      await _ensureMessageListeners();
      final token = await _messaging.getToken();
      if (token == null) {
        _logger.w('Firebase no entregó un token FCM.');
        return;
      }

      await _registerToken(token);
    } catch (error, stackTrace) {
      _logger.e(
        'No se pudo registrar este dispositivo para notificaciones.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _ensureMessageListeners() async {
    _tokenSubscription ??= _messaging.onTokenRefresh.listen(
      (token) => unawaited(_registerRefreshedToken(token)),
    );
    _foregroundSubscription ??= FirebaseMessaging.onMessage.listen(
      (message) => unawaited(_handleForegroundMessage(message)),
    );
    _openedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => unawaited(_handleOpenedMessage(message)),
    );
    if (!_initialMessageHandled) {
      _initialMessageHandled = true;
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) await _handleOpenedMessage(initialMessage);
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification != null) {
      final payload = jsonEncode(message.data);
      await _localNotifications?.showNotification(
        id: message.hashCode,
        title: notification.title ?? 'Comedero IA Edge',
        body: notification.body ?? '',
        payload: payload,
      );
    }
    await onForegroundMessage?.call(message);
  }

  Future<void> _handleOpenedMessage(RemoteMessage message) async {
    await onNotificationOpened?.call(message);
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
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}
