import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance srv) {
  srv.on('stopService').listen((_) {
    srv.stopSelf();
  });
}

class BgServiceManager {
  final FlutterBackgroundService _s = FlutterBackgroundService();
  final FlutterLocalNotificationsPlugin _n = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );
    await _n.initialize(settings: init);

    const ch = AndroidNotificationChannel(
      'transfer_channel',
      'Transfers',
      importance: Importance.low,
    );

    final and = _n
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await and?.requestNotificationsPermission();
    await and?.createNotificationChannel(ch);

    final ios = _n
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    await _s.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        isForegroundMode: true,
        autoStart: false,
        notificationChannelId: 'transfer_channel',
        initialNotificationTitle: 'Relay transfer',
        initialNotificationContent: 'Preparing transfer',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(),
    );
  }

  Future<void> startTransfer(String name) async {
    await _s.startService();
    await _n.show(
      id: 888,
      title: 'Sending $name',
      body: 'Transfer in progress',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'transfer_channel',
          'Transfers',
          importance: Importance.low,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
        ),
      ),
    );
  }

  Future<void> stopTransfer() async {
    _s.invoke('stopService');
    await _n.cancel(id: 888);
  }
}
