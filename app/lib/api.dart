import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

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

  /// Địa chỉ gốc của máy chủ (bỏ "/api"), để mở link tải file.
  String get serverOrigin => baseUrl.endsWith('/api') ? baseUrl.substring(0, baseUrl.length - 4) : baseUrl;

  /// Tải một file lên máy chủ (POST /files). Trả về {id, name, size, mimeType}.
  Future<dynamic> upload(List<int> bytes, String filename) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/files'));
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename, contentType: MediaType.parse(mimeOf(filename))));
    return _run(req, timeout: const Duration(minutes: 5));
  }

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final req = http.Request(method, Uri.parse('$baseUrl$path'))..headers.addAll(_headers);
    if (body != null) req.body = jsonEncode(body);
    return _run(req);
  }

  Future<dynamic> _run(http.BaseRequest req, {Duration timeout = const Duration(seconds: 20)}) async {
    http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(timeout));
    } catch (_) {
      throw ApiException(0, 'Không kết nối được máy chủ ($baseUrl). Kiểm tra máy chủ đã chạy chưa.');
    }
    if (res.statusCode == 413) throw ApiException(413, 'File quá lớn');
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

/// Đoán loại file theo đuôi tên.
String mimeOf(String filename) {
  final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : '';
  return const {
        'pdf': 'application/pdf',
        'png': 'image/png',
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'gif': 'image/gif',
        'webp': 'image/webp',
        'txt': 'text/plain',
        'mp4': 'video/mp4',
        'webm': 'video/webm',
        'mp3': 'audio/mpeg',
        'm4a': 'audio/mp4',
        'doc': 'application/msword',
        'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'xls': 'application/vnd.ms-excel',
        'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'ppt': 'application/vnd.ms-powerpoint',
        'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'zip': 'application/zip',
      }[ext] ??
      'application/octet-stream';
}
