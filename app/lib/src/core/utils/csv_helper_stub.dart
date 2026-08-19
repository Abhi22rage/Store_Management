
void downloadCSV({required String content, required String filename}) {
  throw UnsupportedError(
    'CSV download is not supported on this platform. '
    'Use csv_helper_native.dart (dart:io) or csv_helper_web.dart (dart:html).',
  );
}
