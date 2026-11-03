import 'dart:async';

import 'package:flutter/material.dart';

import '../api_service.dart';
import '../data/recording.dart';

class HomeScreen extends StatefulWidget {
  final List<Recording> recordings;
  final bool loading;
  final ApiService api;
  final void Function(Recording) onOpenResult;
  final VoidCallback onRecord;
  final VoidCallback onPickFile;
  final Future<void> Function(Recording, String) onRename;
  final Future<void> Function(Recording) onDelete;

  const HomeScreen({
    super.key,
    required this.recordings,
    required this.loading,
    required this.api,
    required this.onOpenResult,
    required this.onRecord,
    required this.onPickFile,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? _health;
  bool _healthLoading = true;
  Timer? _retry;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkHealth();
  }

  @override
  void dispose() {
    _retry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _retryCount = 0;
      setState(() => _healthLoading = true);
      _checkHealth();
    }
  }

  Future<void> _checkHealth() async {
    _retry?.cancel();
    final h = await widget.api.checkHealth();
    if (!mounted) return;
    setState(() {
      _health = h;
      _healthLoading = false;
    });
    if (h == null) {
      _retryCount++;
      if (_retryCount <= 24) {
        _retry = Timer(const Duration(seconds: 5), () {
          if (mounted) _checkHealth();
        });
      }
    } else {
      _retryCount = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('VietVoice'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: widget.onPickFile,
            tooltip: 'Nhập tệp âm thanh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onRecord,
        icon: const Icon(Icons.mic),
        label: const Text('Ghi âm'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _retryCount = 0;
          setState(() => _healthLoading = true);
          await _checkHealth();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _modelStatusCard(theme),
            const SizedBox(height: 20),
            Row(
              children: [
                Text('Bản ghi', style: theme.textTheme.titleMedium),
                const SizedBox(width: 8),
                if (widget.recordings.isNotEmpty)
                  Text(
                    '(${widget.recordings.length})',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (widget.recordings.isEmpty)
              _emptyState(theme)
            else
              ...widget.recordings.map((r) => _recordingTile(context, r, theme)),
          ],
        ),
      ),
    );
  }

  Widget _modelStatusCard(ThemeData theme) {
    late final Color color;
    late final String text;
    late final IconData icon;
    if (_healthLoading) {
      color = theme.colorScheme.outline;
      text = 'Đang kiểm tra kết nối...';
      icon = Icons.sync;
    } else if (_health == null) {
      color = Colors.red;
      text = 'Không kết nối được backend · đang thử lại';
      icon = Icons.error_outline;
    } else {
      color = Colors.green;
      text = 'Sẵn sàng · Mô hình: ${_health!['model']}';
      icon = Icons.check_circle;
    }
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: const Text('Trạng thái máy chủ'),
        subtitle: Text(text),
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Kiểm tra lại',
          onPressed: () {
            _retryCount = 0;
            setState(() => _healthLoading = true);
            _checkHealth();
          },
        ),
      ),
    );
  }

  Widget _emptyState(ThemeData theme) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.graphic_eq, size: 64, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text('Chưa có bản ghi nào', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              'Nhấn “Ghi âm” hoặc nhập một tệp âm thanh để bắt đầu.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );

  Widget _recordingTile(BuildContext context, Recording r, ThemeData theme) {
    final preview = r.transcript.replaceAll(RegExp(r'\s+'), ' ').trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(Icons.graphic_eq, color: theme.colorScheme.onPrimaryContainer, size: 20),
        ),
        title: Text(
          r.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (preview.isNotEmpty)
              Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              _meta(r),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
        isThreeLine: preview.isNotEmpty,
        onTap: () => widget.onOpenResult(r),
        onLongPress: () => _showActions(context, r),
      ),
    );
  }

  String _meta(Recording r) {
    final d = r.createdAt;
    final parts = <String>[
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}',
    ];
    if (r.duration != null) {
      final sec = r.duration!.round();
      parts.add(sec >= 60
          ? '${sec ~/ 60} phút ${sec % 60}s'
          : '${sec}s');
    }
    if (r.model != null) parts.add(r.model!);
    return parts.join(' · ');
  }

  void _showActions(BuildContext context, Recording r) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Đổi tên'),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(context, r);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Xóa bản ghi', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, r);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, Recording r) {
    final ctrl = TextEditingController(text: r.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi tên bản ghi'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              final v = ctrl.text.trim();
              Navigator.pop(ctx);
              if (v.isNotEmpty) widget.onRename(r, v);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Recording r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bản ghi?'),
        content: Text('“${r.title}” sẽ bị xóa vĩnh viễn, không thể khôi phục.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete(r);
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}
