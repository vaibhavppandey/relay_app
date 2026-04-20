import 'dart:io';

import 'package:relay_app/pigeons/generated/media_saver.g.dart';

class NativeFilePicker {
  static Future<List<File>> pickFiles({required bool allowMultiple}) async {
    final paths = await MediaSaverApi().pickFiles(allowMultiple);
    return paths
        .where((path) => path.isNotEmpty)
        .map(File.new)
        .where((file) => file.existsSync())
        .toList();
  }
}
