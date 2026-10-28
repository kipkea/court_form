import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  late final Dio _dio;
  String? _token;

  ApiService() {
    String baseUrl = '/api/form/';
    if (kIsWeb) {
      final origin = Uri.base.origin;
      final port = Uri.base.port;
      if (port != 8007 && port != 80 && port != 443 && origin.contains('localhost')) {
        baseUrl = 'http://localhost:8007/api/form/';
      } else {
        baseUrl = '$origin/api/form/';
      }
    } else {
      baseUrl = 'http://localhost:8007/api/form/';
    }

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 60),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null && _token!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        return handler.next(options);
      },
    ));
  }

  void setToken(String? token) {
    _token = token;
  }

  String? get token => _token;

  Future<Map<String, dynamic>> verifySsoTicket(String ticket) async {
    final res = await _dio.post('auth/sso-verify/', data: {'sso_ticket': ticket});
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> loginDirect(String username, String password) async {
    final res = await _dio.post('auth/login/', data: {
      'username': username,
      'password': password,
    });
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> fetchCurrentUser() async {
    final res = await _dio.get('auth/me/');
    return Map<String, dynamic>.from(res.data);
  }

  Future<List<Map<String, dynamic>>> fetchPaperSizes() async {
    final res = await _dio.get('paper-sizes/');
    return List<Map<String, dynamic>>.from(res.data);
  }

  Future<List<Map<String, dynamic>>> fetchTemplates({String? category}) async {
    final res = await _dio.get('templates/', queryParameters: {
      if (category != null && category != 'ALL') 'category': category,
    });
    return List<Map<String, dynamic>>.from(res.data);
  }

  Future<Map<String, dynamic>> createTemplate(Map<String, dynamic> data) async {
    final res = await _dio.post('templates/', data: data);
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> updateTemplate(int id, Map<String, dynamic> data) async {
    final res = await _dio.put('templates/$id/', data: data);
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> duplicateTemplate(int id, {String? name}) async {
    final res = await _dio.post('templates/$id/duplicate/', data: {
      'name': ?name,
    });
    return Map<String, dynamic>.from(res.data);
  }

  Future<void> deleteTemplate(int id) async {
    await _dio.delete('templates/$id/');
  }

  Future<List<Map<String, dynamic>>> fetchDataSources() async {
    final res = await _dio.get('data-sources/');
    return List<Map<String, dynamic>>.from(res.data);
  }

  Future<Map<String, dynamic>> updateDataSource(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('data-sources/$id/', data: data);
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> fetchDataSourceRecords(String sourceCode, {String search = ''}) async {
    final res = await _dio.get(
      'data-sources/$sourceCode/records/',
      queryParameters: {'search': search},
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> parseBatchFile(Uint8List bytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _dio.post('batch/parse-file/', data: formData);
    return Map<String, dynamic>.from(res.data);
  }

  Future<List<Map<String, dynamic>>> fetchPrinterProfiles() async {
    final res = await _dio.get('printer-profiles/');
    return List<Map<String, dynamic>>.from(res.data);
  }

  Future<Map<String, dynamic>> createPrinterProfile(Map<String, dynamic> data) async {
    final res = await _dio.post('printer-profiles/', data: data);
    return Map<String, dynamic>.from(res.data);
  }

  Future<void> deletePrinterProfile(int id) async {
    await _dio.delete('printer-profiles/$id/');
  }

  Future<Map<String, dynamic>> renderForm(Map<String, dynamic> payload) async {
    final res = await _dio.post('render/', data: payload);
    return Map<String, dynamic>.from(res.data);
  }

  Future<List<Map<String, dynamic>>> fetchPrintLogs({
    String search = '',
    String actionType = 'ALL',
    int? templateId,
  }) async {
    final res = await _dio.get('print-logs/', queryParameters: {
      if (search.isNotEmpty) 'search': search,
      if (actionType.isNotEmpty && actionType != 'ALL') 'action_type': actionType,
      if (templateId != null) 'template_id': templateId.toString(),
    });
    return List<Map<String, dynamic>>.from(res.data);
  }

  Future<Map<String, dynamic>> fetchPrintLogSummary() async {
    final res = await _dio.get('print-logs/summary/');
    return Map<String, dynamic>.from(res.data);
  }
}
