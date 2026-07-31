import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';

const _channelId = 'feeder_rounds';
const _channelName = 'Rondas de alimentación';
const _channelDescription =
    'Notificaciones de resultados de rondas del comedero';

class LocalNotificationService {
  LocalNotificationService({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize({
    void Function(String? payload)? onSelectNotification,
  }) async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        onSelectNotification?.call(response.payload);
      },
    );

    _initialized = true;
    _logger.i('Local notifications initialized.');
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) {
      _logger.w('Cannot show notification: service not initialized.');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      ticker: 'Comedero IA Edge',
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }
}
