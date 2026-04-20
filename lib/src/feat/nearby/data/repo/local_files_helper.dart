import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LocalFilesHelper {
  static Future<List<File>> getDownloadedFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.listSync().whereType<File>().toList();
  }
}
