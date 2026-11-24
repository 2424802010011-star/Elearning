import 'package:material_ui/material_ui.dart';

void showMsg(BuildContext context, Object msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg.toString()),
    backgroundColor: error ? Theme.of(context).colorScheme.error : null,
  ));
}

/// Chạy một thao tác, báo lỗi bằng SnackBar nếu có. Trả về true nếu thành công.
Future<bool> runGuarded(BuildContext context, Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (success != null && context.mounted) showMsg(context, success);
    return true;
  } catch (e) {
    if (context.mounted) showMsg(context, e, error: true);
    return false;
  }
}

/// Khung hiển thị dữ liệu tải từ máy chủ: đang tải / lỗi (có nút thử lại) / dữ liệu.
class AsyncView<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;
  const AsyncView({super.key, required this.future, required this.builder, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(snap.error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.tonal(onPressed: onRetry, child: const Text('Thử lại')),
              ]),
            ),
          );
        }
        return builder(snap.data as T);
      },
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState({super.key, required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ]),
        ),
      );
}
