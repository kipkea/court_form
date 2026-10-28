import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';

final Map<String, String> _memoryStorage = {};

String? getSessionItem(String key) => _memoryStorage[key];

void setSessionItem(String key, String value) {
  _memoryStorage[key] = value;
}

void removeSessionItem(String key) {
  _memoryStorage.remove(key);
}

void openExternalUrl(String url) {
  try {
    Process.run('cmd', ['/c', 'start', '', url]);
  } catch (_) {}
}

bool checkPlatformLiteFlag() {
  try {
    if (Platform.environment['COURT_FORM_LITE'] == '1') return true;
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    if (File('$exeDir\\lite_mode.flag').existsSync()) return true;
    if (File('lite_mode.flag').existsSync()) return true;
  } catch (_) {}
  return false;
}

File _getLiteStorageFile() {
  try {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return File('$exeDir\\court_form_lite_data.json');
  } catch (_) {
    return File('court_form_lite_data.json');
  }
}

Future<Map<String, dynamic>?> loadLocalLiteData() async {
  try {
    final file = _getLiteStorageFile();
    if (await file.exists()) {
      final content = await file.readAsString();
      return Map<String, dynamic>.from(jsonDecode(content));
    }
  } catch (_) {}
  return null;
}

Future<void> saveLocalLiteData(Map<String, dynamic> data) async {
  try {
    final file = _getLiteStorageFile();
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  } catch (_) {}
}

Future<void> saveFileBytes(
  Uint8List bytes,
  String filename, {
  String mimeType = 'application/octet-stream',
}) async {
  try {
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : 'pdf';
    final outputUri = await FilePicker.saveFile(
      dialogTitle: 'บันทึกไฟล์แบบพิมพ์ ($filename)',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: [ext],
      bytes: bytes,
    );
    if (outputUri != null) {
      final rawPath = outputUri.toFilePath();
      final finalPath = rawPath.toLowerCase().endsWith('.$ext') ? rawPath : '$rawPath.$ext';
      final f = File(finalPath);
      if (!f.existsSync() || f.lengthSync() == 0) {
        await f.writeAsBytes(bytes, flush: true);
      }
      await Process.run('cmd', ['/c', 'start', '', finalPath]);
    }
  } catch (_) {}
}

Future<void> printPdfBytes(Uint8List pdfBytes) async {
  try {
    final tempDir = Directory.systemTemp;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final tempFile = File('${tempDir.path}\\court_form_print_$ts.pdf');
    await tempFile.writeAsBytes(pdfBytes, flush: true);
    await Process.run('cmd', ['/c', 'start', '', tempFile.path]);
  } catch (_) {}
}

/// สร้างไฟล์ PDF มาตรฐาน 1.4 จากหน้า ui.Image ด้วยขนาดกระดาษหน่วยมิลลิเมตรจริง (ไม่ต้องใช้ Server)
Future<Uint8List> buildMultiPagePdfFromImages(
  List<ui.Image> pages,
  double widthMm,
  double heightMm,
) async {
  final widthPt = widthMm * 72.0 / 25.4;
  final heightPt = heightMm * 72.0 / 25.4;
  final wPtStr = widthPt.toStringAsFixed(2);
  final hPtStr = heightPt.toStringAsFixed(2);

  final out = BytesBuilder();
  final offsets = <int>[0]; // 1-based object offsets

  void writeStr(String s) => out.add(latin1.encode(s));
  void startObj(int id) {
    while (offsets.length <= id) {
      offsets.add(0);
    }
    offsets[id] = out.length;
    writeStr('$id 0 obj\n');
  }

  void endObj() => writeStr('\nendobj\n');

  writeStr('%PDF-1.4\n%\xE2\xE3\xCF\xD3\n');

  // Obj 1: Catalog, Obj 2: Pages
  final pageCount = pages.length;
  final pageObjIds = <int>[];
  int nextId = 3;
  for (int i = 0; i < pageCount; i++) {
    pageObjIds.add(nextId);
    nextId += 3; // pageObj, contentObj, imageObj
  }

  startObj(1);
  writeStr('<< /Type /Catalog /Pages 2 0 R >>');
  endObj();

  startObj(2);
  final kidsStr = pageObjIds.map((id) => '$id 0 R').join(' ');
  writeStr('<< /Type /Pages /Kids [$kidsStr] /Count $pageCount >>');
  endObj();

  for (int i = 0; i < pageCount; i++) {
    final img = pages[i];
    final rgbaData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final rgba = rgbaData!.buffer.asUint8List();
    final pixelCount = img.width * img.height;
    final rgb = Uint8List(pixelCount * 3);
    int src = 0;
    int dst = 0;
    for (int p = 0; p < pixelCount; p++) {
      rgb[dst++] = rgba[src];
      rgb[dst++] = rgba[src + 1];
      rgb[dst++] = rgba[src + 2];
      src += 4;
    }
    final compressedRgb = zlib.encode(rgb);

    final pageId = pageObjIds[i];
    final contentId = pageId + 1;
    final imageId = pageId + 2;

    startObj(pageId);
    writeStr(
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $wPtStr $hPtStr] '
      '/Resources << /XObject << /Im0 $imageId 0 R >> >> '
      '/Contents $contentId 0 R >>',
    );
    endObj();

    final contentStream = 'q $wPtStr 0 0 $hPtStr 0 0 cm /Im0 Do Q\n';
    final contentBytes = latin1.encode(contentStream);
    startObj(contentId);
    writeStr('<< /Length ${contentBytes.length} >>\nstream\n');
    out.add(contentBytes);
    writeStr('endstream');
    endObj();

    startObj(imageId);
    writeStr(
      '<< /Type /XObject /Subtype /Image /Width ${img.width} /Height ${img.height} '
      '/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode '
      '/Length ${compressedRgb.length} >>\nstream\n',
    );
    out.add(compressedRgb);
    writeStr('\nendstream');
    endObj();
  }

  final xrefOffset = out.length;
  final totalObjs = nextId;
  writeStr('xref\n0 $totalObjs\n0000000000 65535 f \n');
  for (int id = 1; id < totalObjs; id++) {
    final off = offsets[id].toString().padLeft(10, '0');
    writeStr('$off 00000 n \n');
  }
  writeStr('trailer\n<< /Size $totalObjs /Root 1 0 R >>\nstartxref\n$xrefOffset\n%%EOF\n');

  return out.toBytes();
}
