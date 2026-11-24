import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../models.dart';
import '../ui.dart';

/// Lịch cả tuần, gộp mọi lớp của người dùng (phụ huynh: lớp của con).
class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});
  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  DateTime _ref = DateTime.now();
  late Future<Map<String, dynamic>> _f;

  String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _dm(String ymd) => '${int.parse(ymd.substring(8))}/${int.parse(ymd.substring(5, 7))}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _f = AppScope.of(context).api.get('/timetable/week?date=${_ymd(_ref)}').then((j) => j as Map<String, dynamic>);

  void _shift(int days) => setState(() {
        _ref = _ref.add(Duration(days: days));
        _load();
      });

  @override
  Widget build(BuildContext context) {
    final today = _ymd(DateTime.now());
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Thời khóa biểu')),
      body: AsyncView<Map<String, dynamic>>(
        future: _f,
        onRetry: () => setState(_load),
        builder: (data) {
          final sessions = [for (final j in data['sessions']) Session.fromJson(j)];
          final start = DateTime.parse(data['weekStart']);
          final days = [for (var i = 0; i < 7; i++) _ymd(start.add(Duration(days: i)))];
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                IconButton(onPressed: () => _shift(-7), icon: const Icon(Icons.chevron_left), tooltip: 'Tuần trước'),
                Expanded(
                  child: Text(
                    'Tuần ${_dm(data['weekStart'])} - ${_dm(data['weekEnd'])}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(onPressed: () => setState(() { _ref = DateTime.now(); _load(); }), child: const Text('Hôm nay')),
                IconButton(onPressed: () => _shift(7), icon: const Icon(Icons.chevron_right), tooltip: 'Tuần sau'),
              ]),
            ),
            Expanded(
              child: sessions.isEmpty
                  ? const EmptyState(icon: Icons.free_breakfast_outlined, text: 'Tuần này không có tiết học')
                  : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                      for (var i = 0; i < 7; i++)
                        if (sessions.any((s) => s.date == days[i])) ...[
                          Container(
                            width: double.infinity,
                            color: days[i] == today ? scheme.primaryContainer : scheme.surfaceContainerHigh,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            child: Text('${dayNames[i]}, ${_dm(days[i])}${days[i] == today ? ' (hôm nay)' : ''}',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          for (final s in sessions.where((s) => s.date == days[i]))
                            ListTile(
                              leading: SizedBox(
                                width: 56,
                                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Text(s.startTime, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text(s.endTime, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                                ]),
                              ),
                              title: Text(s.title),
                              subtitle: Text([s.className, if (s.location != null) s.location!].join(' · ')),
                            ),
                        ],
                    ]),
            ),
          ]);
        },
      ),
    );
  }
}
