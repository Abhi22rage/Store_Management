import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void downloadCSV({required String content, required String filename}) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$filename';
    final file = File(filePath);
    await file.writeAsString(content, flush: true);

    final xFile = XFile(filePath, mimeType: 'text/csv');
    await SharePlus.instance.share(ShareParams(files: [xFile], subject: 'Smart Store Export'));
  } catch (e) {
    debugPrint('Native CSV download failed: $e');
    throw Exception('Failed to export CSV: $e');
  }
}

Future<String?> saveCSVToFile({required String content, required String filename}) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$filename';
    final file = File(filePath);
    await file.writeAsString(content, flush: true);
    return filePath;
  } catch (e) {
    debugPrint('Native CSV save failed: $e');
    return null;
  }
}
