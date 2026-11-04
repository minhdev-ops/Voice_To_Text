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
                Text('Bản ghi', style: theme.textTheme.titleLarge),
                const SizedBox(width: 10),
                if (widget.recordings.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${widget.recordings.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
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
    final Color color;
    final String text;
    final IconData icon;
    if (_healthLoading) {
      color = theme.colorScheme.outline;
      text = 'Đang kiểm tra kết nối...';
      icon = Icons.sync;
    } else if (_health == null) {
      color = const Color(0xFFE5484D);
      text = 'Không kết nối được · đang thử lại';
      icon = Icons.cloud_off;
    } else {
      color = const Color(0xFF2FA96B);
      text = 'Sẵn sàng · ${_health!['model']}';
      icon = Icons.bolt;
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              _retryCount = 0;
              setState(() => _healthLoading = true);
              _checkHealth();
            },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.refresh, size: 18, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(ThemeData theme) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.multitrack_audio_rounded,
                size: 44,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text('Chưa có bản ghi nào', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Nhấn Ghi âm để bắt đầu, hoặc nhập một tệp âm thanh có sẵn.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: widget.onRecord,
              icon: const Icon(Icons.mic),
              label: const Text('Ghi âm đầu tiên'),
            ),
          ],
        ),
      );

  Widget _recordingTile(BuildContext context, Recording r, ThemeData theme) {
    final preview = r.transcript.replaceAll(RegExp(r'\s+'), ' ').trim();
    final border = theme.dividerTheme.color ?? theme.colorScheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.cardTheme.color,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border),
        ),
        child: InkWell(
          onTap: () => widget.onOpenResult(r),
          onLongPress: () => _showActions(context, r),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.graphic_eq,
                    size: 22,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (preview.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.schedule,
                              size: 13, color: theme.colorScheme.outline),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _meta(r),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right,
                    size: 18, color: theme.colorScheme.outlineVariant),
              ],
            ),
          ),
        ),
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
