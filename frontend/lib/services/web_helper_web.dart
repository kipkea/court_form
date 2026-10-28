import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui' as ui;
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

bool checkPlatformLiteFlag() {
  try {
    final mode = Uri.base.queryParameters['mode']?.toLowerCase();
    final lite = Uri.base.queryParameters['lite']?.toLowerCase();
    return mode == 'lite' || mode == 'standalone' || lite == '1' || lite == 'true';
  } catch (_) {
    return false;
  }
}

Future<Map<String, dynamic>?> loadLocalLiteData() async {
  try {
    final raw = web.window.localStorage.getItem('court_form_lite_data');
    if (raw != null && raw.isNotEmpty) {
      return Map<String, dynamic>.from(jsonDecode(raw));
    }
  } catch (_) {}
  return null;
}

Future<void> saveLocalLiteData(Map<String, dynamic> data) async {
  try {
    web.window.localStorage.setItem('court_form_lite_data', jsonEncode(data));
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

Future<Uint8List> buildMultiPagePdfFromImages(
  List<ui.Image> pages,
  double widthMm,
  double heightMm,
) async {
  final firstPng = await pages.first.toByteData(format: ui.ImageByteFormat.png);
  return firstPng!.buffer.asUint8List();
}
