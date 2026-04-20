import 'package:shared_preferences/shared_preferences.dart';

class RecoveryQueue {
  static Future<void> addTransfer(String path, String rCode) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('pending_transfers') ?? [];
    list.removeWhere((item) => item.startsWith('$path|'));
    list.add('$path|$rCode');
    await prefs.setStringList('pending_transfers', list);
  }

  static Future<void> removeTransfer(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('pending_transfers') ?? [];
    list.removeWhere((item) => item.startsWith('$path|'));
    await prefs.setStringList('pending_transfers', list);
  }

  static Future<List<Map<String, String>>> getPendingTransfers() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('pending_transfers') ?? [];
    return list
        .map((item) => item.split('|'))
        .where((parts) => parts.length == 2)
        .map((parts) => {'path': parts[0], 'code': parts[1]})
        .toList();
  }
}
