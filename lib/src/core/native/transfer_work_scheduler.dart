import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:relay_app/src/core/constant/key.dart';
import 'package:relay_app/src/core/util/recovery_queue.dart';
import 'package:relay_app/src/feat/transfer/data/repo/transfer_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:workmanager/workmanager.dart';

class TransferWorkScheduler {
  static const String _androidTaskName = 'relay.transfer.retry';
  static const String _androidPeriodicUniqueName =
      'relay.transfer.retry.periodic';
  static const String _androidOneOffUniqueName = 'relay.transfer.retry.one_off';
  static const String iOSProcessingTaskIdentifier =
      'com.vaibhavp.relay.transfer.processing';
  static const String _iOSProcessingUniqueName = 'relay.transfer.retry.ios';

  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) {
      return;
    }

    await Workmanager().initialize(transferCallbackDispatcher);

    _isInitialized = true;
    await _registerPeriodicRecovery();
    await scheduleDeferredSync();
  }

  static Future<void> scheduleDeferredSync() async {
    if (!_isInitialized) {
      return;
    }

    if (Platform.isAndroid) {
      await Workmanager().registerOneOffTask(
        _androidOneOffUniqueName,
        _androidTaskName,
        initialDelay: const Duration(seconds: 5),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 5),
      );
      return;
    }

    if (Platform.isIOS) {
      await Workmanager().cancelByUniqueName(_iOSProcessingUniqueName);
      await Workmanager().registerProcessingTask(
        _iOSProcessingUniqueName,
        iOSProcessingTaskIdentifier,
        initialDelay: const Duration(seconds: 5),
        constraints: Constraints(networkType: NetworkType.connected),
      );
    }
  }

  static Future<void> _registerPeriodicRecovery() async {
    if (!Platform.isAndroid) {
      return;
    }

    await Workmanager().registerPeriodicTask(
      _androidPeriodicUniqueName,
      _androidTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 5),
    );
  }
}

@pragma('vm:entry-point')
void transferCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    ui.DartPluginRegistrant.ensureInitialized();

    final worker = _TransferRecoveryWorker();
    return worker.run(taskName);
  });
}

class _TransferRecoveryWorker {
  Future<bool> run(String taskName) async {
    final handled =
        taskName == Workmanager.iOSBackgroundTask ||
        taskName == TransferWorkScheduler.iOSProcessingTaskIdentifier ||
        taskName == 'relay.transfer.retry';

    if (!handled) {
      return true;
    }

    final ready = await _ensureSupabaseReady();
    if (!ready) {
      return false;
    }

    final repo = TransferRepository(
      supabase: Supabase.instance.client,
      dio: Dio(),
      uuid: Uuid(),
    );

    var shouldRetry = false;
    final pendingTransfers = await RecoveryQueue.getPendingTransfers();

    for (final item in pendingTransfers) {
      final path = item['path'];
      final code = item['code'];

      if (path == null || path.isEmpty || code == null || code.isEmpty) {
        continue;
      }

      final file = File(path);
      if (!file.existsSync()) {
        await RecoveryQueue.removeTransfer(path);
        continue;
      }

      try {
        await repo.send(file, code, waitForNetwork: false);
      } catch (_) {
        final remaining = await RecoveryQueue.getPendingTransfers();
        if (remaining.any((entry) => entry['path'] == path)) {
          shouldRetry = true;
        }
      }
    }

    return !shouldRetry;
  }

  Future<bool> _ensureSupabaseReady() async {
    try {
      await dotenv.load(fileName: KeyConstants.env);
    } catch (_) {}

    final url = dotenv.env[KeyConstants.supabaseUrl] ?? '';
    final anonKey = dotenv.env[KeyConstants.supabaseAnonKey] ?? '';
    if (url.isEmpty || anonKey.isEmpty) {
      return false;
    }

    try {
      Supabase.instance.client;
      return true;
    } catch (_) {}

    try {
      await Supabase.initialize(url: url, anonKey: anonKey);
      return true;
    } catch (_) {
      try {
        Supabase.instance.client;
        return true;
      } catch (_) {
        return false;
      }
    }
  }
}
