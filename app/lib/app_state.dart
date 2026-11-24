import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';

/// Trạng thái đăng nhập của app: token, người dùng hiện tại, địa chỉ máy chủ.
class AppState extends ChangeNotifier {
  final ApiClient api;
  User? user;
  bool ready = false;

  /// Số thông báo chưa đọc. Tách riêng để cập nhật số trên chuông không làm tải lại các màn hình khác.
  final unread = ValueNotifier<int>(0);
  Timer? _poll;

  /// Hỏi máy chủ số thông báo chưa đọc (30 giây một lần khi đang đăng nhập).
  /// Gặp lỗi 401 thì đăng xuất.
  Future<void> refreshUnread() async {
    if (api.token == null) return;
    try {
      final r = await api.get('/notifications/unread-count');
      unread.value = (r['unreadCount'] as num).toInt();
    } on ApiException catch (e) {
      // Token hết hạn hoặc tài khoản bị admin khóa: đưa về màn hình đăng nhập.
      if (e.status == 401) await logout();
    } catch (_) {}
  }

  void _startPolling() {
    _poll?.cancel();
    refreshUnread();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => refreshUnread());
  }

  AppState({ApiClient? api}) : api = api ?? ApiClient(baseUrl: ApiClient.defaultBaseUrl());

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('baseUrl');
      if (savedUrl != null && !kIsWeb) api.baseUrl = savedUrl;
      api.token = prefs.getString('token');
      if (api.token != null) {
        user = User.fromJson(await api.get('/auth/me'));
        _startPolling();
      }
    } catch (_) {
      api.token = null;
      user = null;
    }
    ready = true;
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    api.baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('baseUrl', api.baseUrl);
    notifyListeners();
  }

  Future<void> _signedIn(Map<String, dynamic> res) async {
    api.token = res['accessToken'];
    user = User.fromJson(res['user']);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', api.token!);
    _startPolling();
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    await _signedIn(await api.post('/auth/login', {'email': email, 'password': password}));
  }

  Future<void> register(String email, String password, String fullName, Role role) async {
    await _signedIn(await api.post('/auth/register', {
      'email': email,
      'password': password,
      'fullName': fullName,
      'role': role.name,
    }));
  }

  Future<void> logout() async {
    _poll?.cancel();
    unread.value = 0;
    api.token = null;
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    notifyListeners();
  }

  bool get isTeacherOrAdmin => user?.role == Role.teacher || user?.role == Role.admin;
}

/// Đưa [AppState] xuống cây widget.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
