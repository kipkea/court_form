import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

String? getSessionItem(String key) {
  try {
    return web.window.sessionStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

void setSessionItem(String key, String value) {
  try {
    web.window.sessionStorage.setItem(key, value);
  } catch (_) {}
}

void removeSessionItem(String key) {
  try {
    web.window.sessionStorage.removeItem(key);
  } catch (_) {}
}

void openExternalUrl(String url) {
  try {
    web.window.location.href = url;
  } catch (_) {}
}

Future<void> saveFileBytes(
  Uint8List bytes,
  String filename, {
  String mimeType = 'application/octet-stream',
}) async {
  try {
    final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = filename;
    anchor.click();
    web.URL.revokeObjectURL(url);
  } catch (e) {
    debugPrint('saveFileBytes error: $e');
  }
}

Future<void> printPdfBytes(Uint8List pdfBytes) async {
  try {
    final blob = web.Blob([pdfBytes.toJS].toJS, web.BlobPropertyBag(type: 'application/pdf'));
    final url = web.URL.createObjectURL(blob);
    web.window.open(url, '_blank');
  } catch (e) {
    debugPrint('printPdfBytes error: $e');
  }
}
