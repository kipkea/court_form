import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/lite_defaults.dart';
import '../services/thai_helper.dart';
import '../services/web_helper.dart';

class FormProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  bool isLiteMode = false;
  bool isLoading = true;
  bool isRendering = false;
  String? errorMessage;

  Map<String, dynamic>? user;
  String portalUrl = 'http://localhost:8888/';

  List<Map<String, dynamic>> paperSizes = [];
  List<Map<String, dynamic>> templates = [];
  List<Map<String, dynamic>> dataSources = [];
  List<Map<String, dynamic>> printerProfiles = [];

  // Active Workspace State
  Map<String, dynamic>? selectedTemplate;
  List<Map<String, dynamic>> activeFields = [];
  Map<String, String> fieldValues = {};
  String? selectedFieldId;

  // Live Paper & Printer Settings
  double paperWidthMm = 210.0;
  double paperHeightMm = 297.0;
  String paperPresetCode = 'A4';
  String backgroundImage = '';
  bool showBackgroundOnScreen = true;
  bool printBackgroundToPaper = false;
  double gridSizeMm = 5.0;
  bool showGrid = true;
  bool snapToGrid = false;
  double zoomScale = 1.0;

  // Printer Offset (mm)
  double offsetXMm = 0.0;
  double offsetYMm = 0.0;
  String activeDataSourceUsed = '';

  // Batch / Mail Merge State
  List<String> batchColumns = [];
  List<Map<String, dynamic>> batchRows = [];
  Map<String, String> batchFieldMapping = {};
  int batchPreviewIndex = 0;
  String batchSourceLabel = '';

  // Admin Print Audit Logs
  List<Map<String, dynamic>> printLogs = [];
  Map<String, dynamic> printLogSummary = {};

  bool get isAuthenticated => isLiteMode || (user != null && _api.token != null);
  bool get isFormAdmin => isLiteMode || (user?['is_form_admin'] == true);
  String get displayName => (user?['display_name'] ?? user?['username'] ?? 'ผู้ใช้งาน').toString();
  String get department => (user?['department'] ?? 'ศาลแขวงเชียงดาว').toString();
  String get position => (user?['position'] ?? 'เจ้าหน้าที่ศาล').toString();
  String get courtName => (user?['court_name'] ?? 'ศาลแขวงเชียงดาว').toString();

  Map<String, dynamic>? get selectedField {
    if (selectedFieldId == null) return null;
    for (final f in activeFields) {
      if (f['id'] == selectedFieldId) return f;
    }
    return null;
  }

  static bool _detectLiteParameter(List<String> cliArgs) {
    const envLite = bool.fromEnvironment('LITE_MODE', defaultValue: false);
    if (envLite) return true;
    for (final arg in cliArgs) {
      final clean = arg.trim().toLowerCase();
      if (clean == '--lite' ||
          clean == '-lite' ||
          clean == 'lite' ||
          clean == '-l' ||
          clean == '--standalone' ||
          clean == '-standalone' ||
          clean == 'standalone') {
        return true;
      }
    }
    return checkPlatformLiteFlag();
  }

  Future<void> initialize({List<String> cliArgs = const []}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    if (_detectLiteParameter(cliArgs)) {
      await switchToLiteMode();
      return;
    }

    try {
      String? ssoTicket = Uri.base.queryParameters['sso_ticket'];
      if (ssoTicket == null || ssoTicket.isEmpty) {
        ssoTicket = getSessionItem('court_sso_ticket');
      }

      if (ssoTicket != null && ssoTicket.isNotEmpty) {
        removeSessionItem('court_sso_ticket');
        final res = await _api.verifySsoTicket(ssoTicket);
        final token = res['token']?.toString();
        if (token != null) {
          _api.setToken(token);
          setSessionItem('court_form_jwt', token);
          user = Map<String, dynamic>.from(res['user'] ?? {});
          portalUrl = (res['portal_url'] ?? portalUrl).toString();
        }
      } else {
        final savedJwt = getSessionItem('court_form_jwt');
        if (savedJwt != null && savedJwt.isNotEmpty) {
          _api.setToken(savedJwt);
          try {
            final meRes = await _api.fetchCurrentUser();
            user = Map<String, dynamic>.from(meRes['user'] ?? {});
            portalUrl = (meRes['portal_url'] ?? portalUrl).toString();
          } catch (_) {
            removeSessionItem('court_form_jwt');
            _api.setToken(null);
          }
        }
      }

      if (isAuthenticated) {
        await loadAllInitialData();
      }
    } catch (e) {
      errorMessage = 'ไม่สามารถเชื่อมต่อระบบแม่ข่ายได้ (สามารถกดปุ่มเข้าใช้งานโหมด Lite ด้านล่างได้ทันที)';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> switchToLiteMode() async {
    isLiteMode = true;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    user = {
      'id': 0,
      'username': 'lite_user',
      'display_name': 'โหมดใช้งานอิสระ (Standalone Lite)',
      'department': 'ไม่ต้องเชื่อมต่อระบบกลาง',
      'position': 'ผู้ใช้งานเครื่องนี้',
      'court_name': 'ศาลแขวงเชียงดาว',
      'is_form_admin': true,
    };

    paperSizes = LiteDefaults.getPaperSizes();
    printerProfiles = LiteDefaults.getPrinterProfiles();
    templates = LiteDefaults.getDefaultTemplates();
    dataSources = [];

    final savedLocal = await loadLocalLiteData();
    if (savedLocal != null) {
      if (savedLocal['templates'] is List && (savedLocal['templates'] as List).isNotEmpty) {
        templates = List<Map<String, dynamic>>.from(
          (savedLocal['templates'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }
      if (savedLocal['printerProfiles'] is List && (savedLocal['printerProfiles'] as List).isNotEmpty) {
        printerProfiles = List<Map<String, dynamic>>.from(
          (savedLocal['printerProfiles'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }
    }

    if (templates.isNotEmpty) {
      selectTemplate(templates.first);
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> _persistLiteState() async {
    if (!isLiteMode) return;
    await saveLocalLiteData({
      'templates': templates,
      'printerProfiles': printerProfiles,
    });
  }

  Future<bool> loginWithCredentials(String username, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final res = await _api.loginDirect(username, password);
      final token = res['token']?.toString();
      if (token != null) {
        _api.setToken(token);
        setSessionItem('court_form_jwt', token);
        user = Map<String, dynamic>.from(res['user'] ?? {});
        portalUrl = (res['portal_url'] ?? portalUrl).toString();
        await loadAllInitialData();
        isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      errorMessage = 'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง หรือไม่ได้เปิดเซิร์ฟเวอร์พอร์ต 8007';
    }
    isLoading = false;
    notifyListeners();
    return false;
  }

  void logoutToPortal() {
    removeSessionItem('court_form_jwt');
    removeSessionItem('court_sso_ticket');
    _api.setToken(null);
    user = null;
    openExternalUrl(portalUrl);
  }

  Future<void> loadAllInitialData() async {
    final results = await Future.wait([
      _api.fetchPaperSizes(),
      _api.fetchTemplates(),
      _api.fetchDataSources(),
      _api.fetchPrinterProfiles(),
    ]);
    paperSizes = results[0];
    templates = results[1];
    dataSources = results[2];
    printerProfiles = results[3];

    if (templates.isNotEmpty && selectedTemplate == null) {
      selectTemplate(templates.first);
    }
    if (isFormAdmin && !isLiteMode) {
      await loadPrintLogs();
    }
    notifyListeners();
  }

  void selectTemplate(Map<String, dynamic> tpl) {
    selectedTemplate = Map<String, dynamic>.from(tpl);
    paperPresetCode = (tpl['paper_preset'] ?? 'A4').toString();
    paperWidthMm = (tpl['width_mm'] as num?)?.toDouble() ?? 210.0;
    paperHeightMm = (tpl['height_mm'] as num?)?.toDouble() ?? 297.0;
    backgroundImage = (tpl['background_image'] ?? '').toString();
    printBackgroundToPaper = tpl['print_background'] == true;
    showBackgroundOnScreen = true;
    gridSizeMm = (tpl['grid_size_mm'] as num?)?.toDouble() ?? 5.0;
    offsetXMm = (tpl['default_offset_x_mm'] as num?)?.toDouble() ?? 0.0;
    offsetYMm = (tpl['default_offset_y_mm'] as num?)?.toDouble() ?? 0.0;
    activeDataSourceUsed = '';

    final rawSchema = tpl['fields_schema'];
    activeFields = [];
    fieldValues = {};
    if (rawSchema is List) {
      for (final item in rawSchema) {
        if (item is Map) {
          final f = Map<String, dynamic>.from(item);
          activeFields.add(f);
          final k = (f['key'] ?? '').toString();
          final defVal = (f['default_value'] ?? '').toString();
          if (k.isNotEmpty) {
            fieldValues[k] = defVal;
          }
        }
      }
    }
    selectedFieldId = activeFields.isNotEmpty ? activeFields.first['id']?.toString() : null;
    notifyListeners();
  }

  void resetPositionsToTemplateDefault() {
    if (selectedTemplate == null) return;
    final savedVals = Map<String, String>.from(fieldValues);
    selectTemplate(selectedTemplate!);
    fieldValues = savedVals;
    notifyListeners();
  }

  void selectField(String? fieldId) {
    selectedFieldId = fieldId;
    notifyListeners();
  }

  void updateFieldValue(String key, String value) {
    fieldValues[key] = value;
    notifyListeners();
  }

  String resolveDisplayTextForField(Map<String, dynamic> field, {Map<String, String>? customValues}) {
    final vals = customValues ?? fieldValues;
    final key = (field['key'] ?? '').toString();
    final ftype = (field['field_type'] ?? 'text').toString();
    final rawVal = vals[key] ?? (field['default_value'] ?? '').toString();

    if (ftype == 'bahttext') {
      final srcKey = (field['source_field'] ?? '').toString();
      final wrap = field['wrap_brackets'] == true;
      if (srcKey.isNotEmpty && (vals[srcKey] ?? '').isNotEmpty) {
        return ThaiHelper.numberToBahtText(vals[srcKey]!, wrapBrackets: wrap);
      }
      if (rawVal.isNotEmpty) {
        return ThaiHelper.numberToBahtText(rawVal, wrapBrackets: wrap);
      }
      return '';
    }
    if (ftype == 'currency') {
      return ThaiHelper.formatCurrency(
        rawVal,
        prefix: (field['prefix'] ?? '').toString(),
        suffix: (field['suffix'] ?? '').toString(),
      );
    }
    if (ftype == 'date_thai') {
      return ThaiHelper.formatThaiDate(
        rawVal,
        format: (field['date_format'] ?? 'full').toString(),
        thaiDigits: field['thai_digits'] == true,
      );
    }
    if (field['thai_digits'] == true) {
      return ThaiHelper.toThaiDigits(rawVal);
    }
    return rawVal;
  }

  void moveFieldPosition(String fieldId, double newXMm, double newYMm) {
    final idx = activeFields.indexWhere((f) => f['id'] == fieldId);
    if (idx < 0) return;

    double x = newXMm;
    double y = newYMm;
    if (snapToGrid && gridSizeMm > 0) {
      x = (x / gridSizeMm).round() * gridSizeMm;
      y = (y / gridSizeMm).round() * gridSizeMm;
    }
    x = x.clamp(0.0, (paperWidthMm - 4.0).clamp(1.0, 1000.0));
    y = y.clamp(0.0, (paperHeightMm - 4.0).clamp(1.0, 1000.0));

    activeFields[idx]['x_mm'] = double.parse(x.toStringAsFixed(1));
    activeFields[idx]['y_mm'] = double.parse(y.toStringAsFixed(1));
    notifyListeners();
  }

  void nudgeSelectedField(double dxMm, double dyMm) {
    final sf = selectedField;
    if (sf == null) return;
    final curX = (sf['x_mm'] as num?)?.toDouble() ?? 0.0;
    final curY = (sf['y_mm'] as num?)?.toDouble() ?? 0.0;
    moveFieldPosition(sf['id'].toString(), curX + dxMm, curY + dyMm);
  }

  void updateSelectedFieldProperty(String prop, dynamic value) {
    final sf = selectedField;
    if (sf == null) return;
    sf[prop] = value;
    notifyListeners();
  }

  void addNewField({String fieldType = 'text', String? customLabel}) {
    final id = 'fld_${DateTime.now().millisecondsSinceEpoch}';
    final key = 'field_${activeFields.length + 1}';
    final label = customLabel ?? 'ช่องข้อมูลใหม่ ${activeFields.length + 1}';
    final newField = <String, dynamic>{
      'id': id,
      'key': key,
      'label': label,
      'field_type': fieldType,
      'x_mm': 25.0,
      'y_mm': 25.0 + (activeFields.length * 6.0) % (paperHeightMm - 35.0),
      'width_mm': fieldType == 'checkbox' ? 6.0 : 80.0,
      'height_mm': fieldType == 'multiline' ? 20.0 : 8.5,
      'font_size': 16.0,
      'font_bold': false,
      'align': 'left',
      'letter_spacing_mm': 5.8,
      'max_boxes': 5,
      'default_value': fieldType == 'checkbox' ? 'true' : label,
      'data_binding_key': '',
      'printable': true,
    };
    activeFields.add(newField);
    fieldValues[key] = newField['default_value'].toString();
    selectedFieldId = id;
    notifyListeners();
  }

  void deleteSelectedField() {
    if (selectedFieldId == null) return;
    activeFields.removeWhere((f) => f['id'] == selectedFieldId);
    selectedFieldId = activeFields.isNotEmpty ? activeFields.first['id'].toString() : null;
    notifyListeners();
  }

  void changePaperSize(String presetCode, double widthMm, double heightMm) {
    paperPresetCode = presetCode;
    paperWidthMm = widthMm;
    paperHeightMm = heightMm;
    notifyListeners();
  }

  void swapOrientation() {
    final tmp = paperWidthMm;
    paperWidthMm = paperHeightMm;
    paperHeightMm = tmp;
    notifyListeners();
  }

  void setBackgroundImageBase64(String base64Uri) {
    backgroundImage = base64Uri;
    showBackgroundOnScreen = true;
    notifyListeners();
  }

  Future<bool> saveCurrentTemplateAsAdmin({
    required String name,
    required String category,
    required String description,
    required String allowedDataSource,
    bool createNew = false,
  }) async {
    if (!isFormAdmin) return false;
    for (final f in activeFields) {
      final k = (f['key'] ?? '').toString();
      if (k.isNotEmpty && fieldValues.containsKey(k)) {
        f['default_value'] = fieldValues[k];
      }
    }

    final payload = <String, dynamic>{
      'name': name,
      'category': category,
      'description': description,
      'paper_preset': paperPresetCode,
      'width_mm': paperWidthMm,
      'height_mm': paperHeightMm,
      'orientation': paperWidthMm >= paperHeightMm ? 'landscape' : 'portrait',
      'background_image': backgroundImage,
      'print_background': printBackgroundToPaper,
      'grid_size_mm': gridSizeMm,
      'default_offset_x_mm': offsetXMm,
      'default_offset_y_mm': offsetYMm,
      'allowed_data_source': allowedDataSource,
      'fields_schema': jsonDecode(jsonEncode(activeFields)),
      'is_active': true,
    };

    if (isLiteMode) {
      if (createNew || selectedTemplate == null) {
        final newId = DateTime.now().millisecondsSinceEpoch;
        payload['id'] = newId;
        payload['code'] = 'lite_$newId';
        templates.add(payload);
        selectTemplate(payload);
      } else {
        final id = selectedTemplate!['id'];
        payload['id'] = id;
        payload['code'] = selectedTemplate!['code'] ?? 'lite_$id';
        final idx = templates.indexWhere((t) => t['id'] == id);
        if (idx >= 0) {
          templates[idx] = payload;
        } else {
          templates.add(payload);
        }
        selectTemplate(payload);
      }
      await _persistLiteState();
      notifyListeners();
      return true;
    }

    if (createNew || selectedTemplate == null || selectedTemplate!['id'] == null) {
      payload['code'] = 'tpl_${DateTime.now().millisecondsSinceEpoch}';
      final created = await _api.createTemplate(payload);
      templates = await _api.fetchTemplates();
      selectTemplate(created);
    } else {
      final id = selectedTemplate!['id'] as int;
      payload['code'] = selectedTemplate!['code'];
      final updated = await _api.updateTemplate(id, payload);
      templates = await _api.fetchTemplates();
      selectTemplate(updated);
    }
    notifyListeners();
    return true;
  }

  Future<void> duplicateTemplateById(int id) async {
    if (!isFormAdmin) return;
    if (isLiteMode) {
      final orig = templates.firstWhere((t) => t['id'] == id);
      final copy = Map<String, dynamic>.from(jsonDecode(jsonEncode(orig)));
      final newId = DateTime.now().millisecondsSinceEpoch;
      copy['id'] = newId;
      copy['code'] = '${orig['code']}_copy';
      copy['name'] = '${orig['name']} (สำเนา)';
      templates.add(copy);
      await _persistLiteState();
      selectTemplate(copy);
      notifyListeners();
      return;
    }
    final copy = await _api.duplicateTemplate(id);
    templates = await _api.fetchTemplates();
    selectTemplate(copy);
    notifyListeners();
  }

  Future<void> deleteTemplateById(int id) async {
    if (!isFormAdmin) return;
    if (isLiteMode) {
      templates.removeWhere((t) => t['id'] == id);
      await _persistLiteState();
      if (templates.isNotEmpty) {
        selectTemplate(templates.first);
      }
      notifyListeners();
      return;
    }
    await _api.deleteTemplate(id);
    templates = await _api.fetchTemplates();
    if (templates.isNotEmpty) {
      selectTemplate(templates.first);
    } else {
      selectedTemplate = null;
      activeFields = [];
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> queryDataSourceRecords(String sourceCode, {String search = ''}) async {
    return await _api.fetchDataSourceRecords(sourceCode, search: search);
  }

  void applyDataSourceRecordToForm(String sourceCode, Map<String, dynamic> record) {
    activeDataSourceUsed = sourceCode;
    for (final f in activeFields) {
      final fKey = (f['key'] ?? '').toString();
      final bindKey = (f['data_binding_key'] ?? '').toString();
      if (bindKey.isNotEmpty && record.containsKey(bindKey)) {
        fieldValues[fKey] = (record[bindKey] ?? '').toString();
      } else if (record.containsKey(fKey)) {
        fieldValues[fKey] = (record[fKey] ?? '').toString();
      }
    }
    notifyListeners();
  }

  void loadDataSourceRecordsIntoBatch(
    String sourceCode,
    String sourceLabel,
    List<Map<String, dynamic>> records,
    List<Map<String, dynamic>> fieldsMeta,
  ) {
    batchSourceLabel = '$sourceLabel (${records.length} รายการ)';
    batchColumns = fieldsMeta.map((e) => e['key'].toString()).toList();
    batchRows = records;
    batchPreviewIndex = 0;
    activeDataSourceUsed = sourceCode;

    batchFieldMapping = {};
    for (final f in activeFields) {
      final fKey = (f['key'] ?? '').toString();
      final bindKey = (f['data_binding_key'] ?? '').toString();
      if (bindKey.isNotEmpty && batchColumns.contains(bindKey)) {
        batchFieldMapping[fKey] = bindKey;
      } else if (batchColumns.contains(fKey)) {
        batchFieldMapping[fKey] = fKey;
      }
    }
    notifyListeners();
  }

  Future<void> uploadAndParseBatchFile(Uint8List bytes, String filename) async {
    if (isLiteMode) {
      final parsed = LiteDefaults.parseCsvLocally(bytes);
      batchColumns = List<String>.from(parsed['columns'] ?? []);
      batchRows = List<Map<String, dynamic>>.from(parsed['rows'] ?? []);
      batchSourceLabel = 'ไฟล์ $filename (${batchRows.length} แถว)';
      batchPreviewIndex = 0;
      activeDataSourceUsed = 'local_file:$filename';
    } else {
      final res = await _api.parseBatchFile(bytes, filename);
      batchSourceLabel = 'ไฟล์ $filename (${res['row_count']} แถว)';
      batchColumns = List<String>.from(res['columns'] ?? []);
      batchRows = List<Map<String, dynamic>>.from(res['rows'] ?? []);
      batchPreviewIndex = 0;
      activeDataSourceUsed = 'file:$filename';
    }

    batchFieldMapping = {};
    for (final f in activeFields) {
      final fKey = (f['key'] ?? '').toString();
      final fLabel = (f['label'] ?? '').toString();
      for (final col in batchColumns) {
        if (col.toLowerCase() == fKey.toLowerCase() || col == fLabel) {
          batchFieldMapping[fKey] = col;
          break;
        }
      }
    }
    notifyListeners();
  }

  Map<String, String> buildMappedValuesForRow(Map<String, dynamic> row) {
    final out = Map<String, String>.from(fieldValues);
    for (final f in activeFields) {
      final fKey = (f['key'] ?? '').toString();
      final mappedCol = batchFieldMapping[fKey];
      if (mappedCol != null && mappedCol.isNotEmpty && row.containsKey(mappedCol)) {
        out[fKey] = (row[mappedCol] ?? '').toString();
      }
    }
    return out;
  }

  Future<void> executeRenderAction(String actionType, {List<Map<String, String>>? customRecords}) async {
    isRendering = true;
    notifyListeners();
    try {
      final code = (selectedTemplate?['code'] ?? 'form').toString();
      final ts = DateTime.now().millisecondsSinceEpoch;

      // โหมด Lite Standalone: เรนเดอร์ PDF / PNG ภายในเครื่อง 100% ไม่ต้องใช้ Server
      if (isLiteMode) {
        final records = (customRecords != null && customRecords.isNotEmpty)
            ? customRecords
            : <Map<String, String>>[fieldValues];

        if (actionType == 'EXPORT_PNG') {
          final pngBytes = await LiteDefaults.renderLocalPngBytes(
            widthMm: paperWidthMm,
            heightMm: paperHeightMm,
            fieldsSchema: activeFields,
            values: records.first,
            backgroundImageBase64: backgroundImage,
            printBackground: printBackgroundToPaper,
            offsetXMm: offsetXMm,
            offsetYMm: offsetYMm,
          );
          await saveFileBytes(pngBytes, '${code}_$ts.png', mimeType: 'image/png');
        } else {
          final uiPages = <ui.Image>[];
          for (final rec in records) {
            final pageImg = await LiteDefaults.renderPageAsUiImage(
              widthMm: paperWidthMm,
              heightMm: paperHeightMm,
              fieldsSchema: activeFields,
              values: rec,
              backgroundImageBase64: backgroundImage,
              printBackground: printBackgroundToPaper,
              offsetXMm: offsetXMm,
              offsetYMm: offsetYMm,
              dpi: 240.0,
            );
            uiPages.add(pageImg);
          }
          final pdfBytes = await buildMultiPagePdfFromImages(uiPages, paperWidthMm, paperHeightMm);
          if (actionType == 'PRINT') {
            await printPdfBytes(pdfBytes);
          } else {
            await saveFileBytes(pdfBytes, '${code}_$ts.pdf', mimeType: 'application/pdf');
          }
        }
        return;
      }

      // โหมด Full Enterprise: เรนเดอร์ผ่าน Server + บันทึก FormPrintLog
      final payload = <String, dynamic>{
        'action_type': actionType,
        'template_id': selectedTemplate?['id'],
        'template_code': code,
        'template_name': selectedTemplate?['name'] ?? 'แบบพิมพ์กำหนดเอง',
        'paper_size_label': '$paperPresetCode (${paperWidthMm.toStringAsFixed(0)}×${paperHeightMm.toStringAsFixed(0)} มม.)',
        'width_mm': paperWidthMm,
        'height_mm': paperHeightMm,
        'fields_schema': activeFields,
        'values': fieldValues,
        if (customRecords != null && customRecords.isNotEmpty) 'records': customRecords,
        'background_image': backgroundImage,
        'print_background': printBackgroundToPaper,
        'offset_x_mm': offsetXMm,
        'offset_y_mm': offsetYMm,
        'data_source_used': activeDataSourceUsed,
      };

      final res = await _api.renderForm(payload);
      final b64 = (res['file_base64'] ?? '').toString();
      final filename = (res['filename'] ?? 'court_form.pdf').toString();
      final mime = (res['mime_type'] ?? 'application/pdf').toString();
      final bytes = base64Decode(b64);

      if (actionType == 'PRINT') {
        await printPdfBytes(bytes);
      } else {
        await saveFileBytes(bytes, filename, mimeType: mime);
      }

      if (isFormAdmin) {
        await loadPrintLogs();
      }
    } finally {
      isRendering = false;
      notifyListeners();
    }
  }

  Future<void> updateDataSourceSetting(int id, Map<String, dynamic> patchData) async {
    if (isLiteMode) return;
    await _api.updateDataSource(id, patchData);
    dataSources = await _api.fetchDataSources();
    notifyListeners();
  }

  Future<void> loadPrintLogs({String search = '', String actionType = 'ALL', int? templateId}) async {
    if (isLiteMode) return;
    final results = await Future.wait([
      _api.fetchPrintLogs(search: search, actionType: actionType, templateId: templateId),
      _api.fetchPrintLogSummary(),
    ]);
    printLogs = results[0] as List<Map<String, dynamic>>;
    printLogSummary = results[1] as Map<String, dynamic>;
    notifyListeners();
  }
}
