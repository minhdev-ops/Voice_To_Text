import 'dart:async';

import 'package:flutter/material.dart';

import '../api_service.dart';

/// UI-11: Quan ly mo hinh Whisper - xem, tai ve, xoa.
class ModelsScreen extends StatefulWidget {
  final ApiService api;

  const ModelsScreen({super.key, required this.api});

  @override
  State<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends State<ModelsScreen> {
  Map<String, dynamic>? _status;
  bool _loading = true;
  String? _error;
  Timer? _poll;
  String? _busyName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final st = await widget.api.modelsStatus();
    if (!mounted) return;
    setState(() {
      _status = st;
      _loading = false;
      _error = st == null ? 'Không kết nối được backend' : null;
    });
    if (st != null) {
      final dl = st['download'] as Map?;
      if (dl != null && dl['status'] == 'downloading') _startPoll();
    }
  }

  void _startPoll() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) async {
      final dl = await widget.api.modelDownloadStatus();
      if (!mounted) return;
      final st = await widget.api.modelsStatus();
      if (!mounted) return;
      setState(() {
        _status = st;
        if (dl == null || dl['status'] != 'downloading') _poll?.cancel();
      });
    });
  }

  Future<void> _download(String name) async {
    setState(() => _busyName = name);
    final r = await widget.api.modelDownload(name);
    setState(() => _busyName = null);
    if (r != null && (r['status'] == 'downloading' || r['status'] == 'installed')) {
      _startPoll();
    } else {
      setState(() => _error = 'Không thể bắt đầu tải $name');
    }
  }

  Future<void> _delete(String name) async {
    setState(() => _busyName = name);
    final r = await widget.api.modelDelete(name);
    setState(() => _busyName = null);
    if (r != null) {
      _load();
    } else {
      setState(() => _error = 'Không thể xóa $name');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final models = (_status?['models'] as List?) ?? [];
    final dl = _status?['download'] as Map?;
    final downloading = dl != null && dl['status'] == 'downloading';
    final dlName = dl?['name'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý mô hình'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red)),
                  ),
                if (downloading)
                  Card(
                    color: theme.colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Đang tải: $dlName',
                              style: theme.textTheme.titleSmall),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: _progressValue(dl),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _progressText(dl),
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                ...models.map((m) {
                  final mm = m as Map<String, dynamic>;
                  final installed = mm['installed'] == true;
                  final isDefault = mm['is_default'] == true;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${mm['name']}  ·  ${mm['params']}',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              if (installed)
                                Chip(
                                  label: const Text('Đã cài'),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor:
                                      Colors.green.withOpacity(0.15),
                                ),
                              if (isDefault)
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Chip(
                                    label: Text('Mặc định'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${mm['quality']} · ${_fmtMb(mm['disk_bytes'] ?? 0, mm['size_mb'] ?? 0)} · ${mm['languages']}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.outline),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (installed)
                                if (!isDefault)
                                  TextButton.icon(
                                    onPressed: _busyName == mm['name']
                                        ? null
                                        : () => _delete(mm['name']),
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red),
                                    label: const Text('Xóa',
                                        style: TextStyle(color: Colors.red)),
                                  )
                                else
                                  const Text('Đang dùng',
                                      style: TextStyle(color: Colors.grey))
                              else
                                FilledButton.icon(
                                  onPressed: _busyName == mm['name']
                                      ? null
                                      : () => _download(mm['name']),
                                  icon: _busyName == mm['name']
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.download),
                                  label: Text(
                                      _busyName == mm['name'] ? 'Đang tải...' : 'Tải về'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                Text(
                  'Mô hình được tải về từ Hugging Face (Systran/faster-whisper) và lưu trên máy tính này. Càng lớn càng chính xác nhưng càng tốn RAM và thời gian.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
    );
  }

  double _progressValue(Map? dl) {
    if (dl == null) return 0;
    final got = (dl['disk_bytes'] ?? 0) as int;
    final total = (dl['total_bytes'] ?? 0) as int;
    if (total <= 0) return 0;
    return (got / total).clamp(0.0, 1.0);
  }

  String _progressText(Map? dl) {
    if (dl == null) return '';
    final got = (dl['disk_bytes'] ?? 0) as int;
    final total = (dl['total_bytes'] ?? 0) as int;
    return '${_mb(got)} / ${_mb(total)}';
  }

  String _mb(int b) {
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '${(b / 1024 / 1024).toStringAsFixed(0)} MB';
  }

  String _fmtMb(int disk, int catalogMb) {
    if (disk > 0) return _mb(disk);
    return '${catalogMb} MB (dự kiến)';
  }
}
