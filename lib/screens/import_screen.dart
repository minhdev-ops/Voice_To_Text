import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../api_service.dart';
import '../data/recording.dart';
import 'result_screen.dart';

/// UI-03: Nhập tệp âm thanh co san de chep loi (khong can ghi am).
class ImportScreen extends StatefulWidget {
  final ApiService api;
  final String language;
  final String model;
  final Future<Recording?> Function(Map<String, dynamic>) onCompleted;

  const ImportScreen({
    super.key,
    required this.api,
    required this.language,
    required this.model,
    required this.onCompleted,
  });

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  File? _file;
  String? _name;
  String? _error;
  bool _loadingInfo = false;
  Duration _duration = Duration.zero;
  bool _diarize = false;
  final _speakersCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _speakersCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
      withData: false,
    );
    if (res == null || res.files.single.path == null) return;
    final f = File(res.files.single.path!);
    if (!await f.exists()) {
      setState(() => _error = 'Không thể mở tệp này.');
      return;
    }
    setState(() {
      _file = f;
      _name = res.files.single.name;
      _error = null;
      _duration = Duration.zero;
    });
    _readDuration(f.path);
  }

  Future<void> _readDuration(String path) async {
    setState(() => _loadingInfo = true);
    try {
      final player = AudioPlayer();
      await player.setFilePath(path);
      if (mounted) setState(() => _duration = player.duration ?? Duration.zero);
      await player.dispose();
    } catch (_) {}
    if (mounted) setState(() => _loadingInfo = false);
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  Future<void> _start() async {
    if (_file == null) return;
    setState(() => _busy = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final name = p.basename(_file!.path);
      final dest = p.join(dir.path, 'recordings',
          'rec_${DateTime.now().millisecondsSinceEpoch}${p.extension(name)}');
      await Directory(p.dirname(dest)).create(recursive: true);
      await _file!.copy(dest);

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultLoadRoute(
            api: widget.api,
            filePath: dest,
            filename: p.basename(dest),
            language: widget.language,
            model: widget.model,
            diarize: _diarize,
            numSpeakers: int.tryParse(_speakersCtrl.text.trim()),
            audioPath: dest,
            onCompleted: widget.onCompleted,
          ),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = 'Lỗi: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Nhập tệp âm thanh')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.audio_file),
              title: Text(_name ?? 'Chưa chọn tệp nào'),
              subtitle: _file == null
                  ? const Text('Chọn một file âm thanh từ thiết bị')
                  : FutureBuilder<int>(
                      future: _file!.length(),
                      builder: (c, snap) => Text(_loadingInfo
                          ? 'Đang đọc...'
                          : '${_fmtSize(snap.data ?? 0)} · '
                              '${_duration.inMinutes}:'
                              '${(_duration.inSeconds % 60).toString().padLeft(2, '0')}'),
                    ),
              trailing: TextButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.folder_open),
                label: const Text('Chọn'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Phân biệt người nói'),
            subtitle: const Text('Tự động gán nhãn SPK_1, SPK_2... theo giọng'),
            value: _diarize,
            onChanged: (v) => setState(() => _diarize = v),
          ),
          if (_diarize)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _speakersCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số người nói (tùy chọn)',
                  hintText: 'Để trống để tự động nhận',
                ),
              ),
            ),
          const SizedBox(height: 24),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          FilledButton.icon(
            onPressed: _file == null || _busy ? null : _start,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_fix_high),
            label: Text(_busy ? 'Đang chuẩn bị...' : 'Bắt đầu nhận dạng'),
          ),
          const SizedBox(height: 12),
          Text(
            'Tệp sẽ được sao chép vào bộ nhớ ứng dụng để phát lại và lưu trữ.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
