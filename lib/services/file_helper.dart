import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileHelper {
  static Future<File> savePermanently(File file) async {
    final dir = await getApplicationDocumentsDirectory();

    final newPath =
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    return file.copy(newPath);
  }
}