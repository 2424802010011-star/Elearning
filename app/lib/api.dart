import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}

/// Gọi REST API của backend. Lỗi trả về được chuyển thành [ApiException] với thông báo tiếng Việt.
class ApiClient {
  String baseUrl;
  String? token;
  final http.Client _http;

  ApiClient({required this.baseUrl, this.token, http.Client? client}) : _http = client ?? http.Client();

  /// Chạy trên web thì gọi cùng địa chỉ trang; app cài máy thì mặc định máy chủ chạy trên máy này.
  static String defaultBaseUrl() {
    if (kIsWeb) return '${Uri.base.origin}/api';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:3000/api';
    return 'http://localhost:3000/api';
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body);
  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body);
  Future<dynamic> patch(String path, [Object? body]) => _send('PATCH', path, body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final req = http.Request(method, Uri.parse('$baseUrl$path'))..headers.addAll(_headers);
    if (body != null) req.body = jsonEncode(body);
    http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 20)));
    } catch (_) {
      throw ApiException(0, 'Không kết nối được máy chủ ($baseUrl). Kiểm tra máy chủ đã chạy chưa.');
    }
    final text = utf8.decode(res.bodyBytes);
    final data = text.isEmpty ? null : jsonDecode(text);
    if (res.statusCode >= 400) {
      var msg = 'Lỗi ${res.statusCode}';
      if (data is Map && data['message'] != null) {
        final m = data['message'];
        msg = m is List ? m.join('\n') : m.toString();
      }
      throw ApiException(res.statusCode, msg);
    }
    return data;
  }
}
