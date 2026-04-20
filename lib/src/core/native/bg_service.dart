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
    await and?.createNotificationChannel(ch);

    await _s.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        isForegroundMode: false,
        autoStart: false,
        notificationChannelId: 'transfer_channel',
      ),
      iosConfiguration: IosConfiguration(),
    );
  }

  void startTransfer(String name) {
    _s.startService();
    _n.show(
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

  void stopTransfer() {
    _s.invoke('stopService');
    _n.cancel(id: 888);
  }
}
