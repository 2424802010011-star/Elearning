import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../models.dart';
import '../ui.dart';

/// Dung lượng tối đa mỗi file (khớp MAX_UPLOAD_MB mặc định của máy chủ).
const kMaxUploadBytes = 50 * 1024 * 1024;

IconData fileIcon(FileRef f) {
  final m = f.mimeType;
  if (m.startsWith('image/')) return Icons.image_outlined;
  if (m.startsWith('video/')) return Icons.movie_outlined;
  if (m.startsWith('audio/')) return Icons.audiotrack_outlined;
  if (m == 'application/pdf') return Icons.picture_as_pdf_outlined;
  if (m.contains('presentation') || m.contains('powerpoint')) return Icons.slideshow_outlined;
  if (m.contains('sheet') || m.contains('excel')) return Icons.table_chart_outlined;
  if (m.contains('word')) return Icons.description_outlined;
  return Icons.insert_drive_file_outlined;
}

/// Mở file: xin link tải có hạn rồi mở trong trình duyệt / ứng dụng mặc định.
Future<void> openFile(BuildContext context, FileRef f) async {
  final api = AppScope.of(context).api;
  await runGuarded(context, () async {
    final r = await api.get('/files/${f.id}/link');
    final uri = Uri.parse('${api.serverOrigin}${r['url']}');
    if (!await launchUrl(uri, webOnlyWindowName: '_blank')) throw 'Không mở được file';
  });
}

/// Nút hiển thị một file đính kèm, bấm để mở.
class FileChip extends StatelessWidget {
  final FileRef file;
  final VoidCallback? onRemove;
  const FileChip({super.key, required this.file, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final label = Text('${file.name} · ${fmtSize(file.size)}', overflow: TextOverflow.ellipsis);
    if (onRemove != null) {
      return InputChip(avatar: Icon(fileIcon(file), size: 18), label: label, onPressed: () => openFile(context, file), onDeleted: onRemove);
    }
    return ActionChip(avatar: Icon(fileIcon(file), size: 18), label: label, onPressed: () => openFile(context, file), tooltip: 'Mở file');
  }
}

class FileList extends StatelessWidget {
  final List<FileRef> files;
  const FileList(this.files, {super.key});
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 4, children: [for (final f in files) ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360), child: FileChip(file: f))]);
}

/// Chọn và tải file lên. Danh sách file đã tải lên được báo qua [onChanged].
class AttachmentPicker extends StatefulWidget {
  final List<FileRef> initial;
  final ValueChanged<List<FileRef>> onChanged;
  final bool enabled;
  final String label;
  const AttachmentPicker({super.key, this.initial = const [], required this.onChanged, this.enabled = true, this.label = 'Đính kèm file'});
  @override
  State<AttachmentPicker> createState() => _AttachmentPickerState();
}

class _AttachmentPickerState extends State<AttachmentPicker> {
  late final List<FileRef> _files = List.of(widget.initial);
  final List<String> _uploading = [];

  Future<void> _pick() async {
    final api = AppScope.of(context).api;
    final picked = await FilePicker.pickFiles();
    if (picked.isEmpty || !mounted) return;
    for (final p in picked) {
      final size = p.lengthSync() ?? await p.length() ?? 0;
      if (!mounted) return;
      if (size > kMaxUploadBytes) {
        showMsg(context, '${p.name} lớn hơn 50 MB, không tải lên được', error: true);
        continue;
      }
      setState(() => _uploading.add(p.name));
      await runGuarded(context, () async {
        final r = await api.upload(await p.readAsBytes(), p.name);
        _files.add(FileRef.fromJson(r));
        widget.onChanged(List.of(_files));
      });
      if (mounted) setState(() => _uploading.remove(p.name));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Wrap(spacing: 8, runSpacing: 4, children: [
        for (final f in _files)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: FileChip(
              file: f,
              onRemove: widget.enabled
                  ? () {
                      setState(() => _files.remove(f));
                      widget.onChanged(List.of(_files));
                    }
                  : null,
            ),
          ),
        for (final n in _uploading)
          Chip(
            avatar: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            label: Text('Đang tải lên $n'),
          ),
      ]),
      if (widget.enabled)
        TextButton.icon(
          onPressed: _uploading.isEmpty ? _pick : null,
          icon: const Icon(Icons.attach_file),
          label: Text(widget.label),
        ),
    ]);
  }
}
