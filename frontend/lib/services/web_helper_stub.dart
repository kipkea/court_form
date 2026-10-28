import 'dart:typed_data';

String? getSessionItem(String key) => null;
void setSessionItem(String key, String value) {}
void removeSessionItem(String key) {}
void openExternalUrl(String url) {}
Future<void> saveFileBytes(Uint8List bytes, String filename, {String mimeType = 'application/octet-stream'}) async {}
Future<void> printPdfBytes(Uint8List pdfBytes) async {}
