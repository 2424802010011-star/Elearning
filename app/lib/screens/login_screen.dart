import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../models.dart';
import '../ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  Role _role = Role.student;

  static const _demo = {
    'Giáo viên': 'giaovien@demo.vn',
    'Học sinh': 'hocsinh1@demo.vn',
    'Phụ huynh': 'phuhuynh@demo.vn',
    'Admin': 'admin@demo.vn',
  };

  Future<void> _submit() async {
    final app = AppScope.of(context);
    setState(() => _busy = true);
    await runGuarded(context, () async {
      if (_registering) {
        await app.register(_email.text.trim(), _password.text, _name.text.trim(), _role);
      } else {
        await app.login(_email.text.trim(), _password.text);
      }
    });
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _editServer() async {
    final app = AppScope.of(context);
    final ctl = TextEditingController(text: app.api.baseUrl);
    final url = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Địa chỉ máy chủ'),
        content: TextField(controller: ctl, decoration: const InputDecoration(hintText: 'http://192.168.1.10:3000/api')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(c, ctl.text), child: const Text('Lưu')),
        ],
      ),
    );
    if (url != null && url.isNotEmpty) await app.setBaseUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Icon(Icons.draw_rounded, size: 56, color: scheme.primary),
              const SizedBox(height: 8),
              Text('EduBoard', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
              Text('Học tập, giảng dạy và quản lý lớp học',
                  textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 28),
              if (_registering) ...[
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Họ và tên')),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(labelText: _registering ? 'Mật khẩu (tối thiểu 8 ký tự)' : 'Mật khẩu'),
                onSubmitted: (_) => _submit(),
              ),
              if (_registering) ...[
                const SizedBox(height: 16),
                SegmentedButton<Role>(
                  segments: [
                    for (final r in [Role.student, Role.teacher, Role.parent])
                      ButtonSegment(value: r, label: Text(roleLabel(r))),
                  ],
                  selected: {_role},
                  onSelectionChanged: (s) => setState(() => _role = s.first),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_busy ? 'Đang xử lý...' : (_registering ? 'Đăng ký' : 'Đăng nhập')),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _registering = !_registering),
                child: Text(_registering ? 'Đã có tài khoản? Đăng nhập' : 'Chưa có tài khoản? Đăng ký'),
              ),
              if (!_registering) ...[
                const Divider(height: 32),
                Text('Dùng thử nhanh (mật khẩu demo1234)',
                    textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in _demo.entries)
                      ActionChip(
                        label: Text(e.key),
                        onPressed: () {
                          _email.text = e.value;
                          _password.text = 'demo1234';
                          _submit();
                        },
                      ),
                  ],
                ),
              ],
              if (!kIsWeb)
                TextButton.icon(
                  onPressed: _editServer,
                  icon: const Icon(Icons.dns_outlined, size: 18),
                  label: const Text('Đổi địa chỉ máy chủ'),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
