import 'package:shared_preferences/shared_preferences.dart';

class RecoveryQueue {
  static const _pendingTransfersKey = 'pending_transfers';
  static const _pendingDownloadsKey = 'pending_downloads';

  static Future<void> addTransfer(String path, String rCode) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_pendingTransfersKey) ?? [];
    list.removeWhere((item) => item.startsWith('$path|'));
    list.add('$path|$rCode');
    await prefs.setStringList(_pendingTransfersKey, list);
  }

  static Future<void> removeTransfer(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_pendingTransfersKey) ?? [];
    list.removeWhere((item) => item.startsWith('$path|'));
    await prefs.setStringList(_pendingTransfersKey, list);
  }

  static Future<List<Map<String, String>>> getPendingTransfers() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_pendingTransfersKey) ?? [];
    return list
        .map((item) => item.split('|'))
        .where((parts) => parts.length == 2)
        .map((parts) => {'path': parts[0], 'code': parts[1]})
        .toList();
  }

  static Future<void> addDownload(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_pendingDownloadsKey) ?? [];
    if (!list.contains(id)) {
      list.add(id);
      await prefs.setStringList(_pendingDownloadsKey, list);
    }
  }

  static Future<void> removeDownload(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_pendingDownloadsKey) ?? [];
    list.removeWhere((item) => item == id);
    await prefs.setStringList(_pendingDownloadsKey, list);
  }

  static Future<List<String>> getPendingDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_pendingDownloadsKey) ?? [];
  }
}
