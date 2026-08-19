import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

void downloadCSV({required String content, required String filename}) {
  final bytes = utf8.encode(content).toJS;
  final blob = web.Blob(
    [bytes].toJS,
    web.BlobPropertyBag(type: 'text/csv'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
