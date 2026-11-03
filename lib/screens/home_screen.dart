import 'dart:async';

import 'package:flutter/material.dart';
import '../api_service.dart';

class HomeScreen extends StatefulWidget {
  final List<Map<String, dynamic>> recordings;
  final ApiService api;
  final void Function(Map<String, dynamic>) onOpenResult;
  final VoidCallback onRecord;
  final VoidCallback onPickFile;

  const HomeScreen({
    super.key,
    required this.recordings,
    required this.api,
    required this.onOpenResult,
    required this.onRecord,
    required this.onPickFile,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? _health;
  bool _healthLoading = true;
  Timer? _retry;

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
      // Thu lai moi 5 giay cho den khi ket noi duoc (toi da 24 lan ~ 2 phut).
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

  int _retryCount = 0;

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _modelStatusCard(theme),
          const SizedBox(height: 16),
          Text('Bản ghi gần đây', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (widget.recordings.isEmpty)
            _emptyState()
          else
            ...widget.recordings.map((r) => _recordingTile(context, r, theme)),
        ],
      ),
    );
  }

  Widget _modelStatusCard(ThemeData theme) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (_healthLoading) {
      statusColor = Colors.grey;
      statusText = 'Đang kiểm tra...';
      statusIcon = Icons.hourglass_empty;
    } else if (_health == null) {
      statusColor = Colors.red;
      statusText = 'Không kết nối được backend';
      statusIcon = Icons.error_outline;
    } else {
      statusColor = Colors.green;
      statusText = 'Sẵn sàng · Mô hình: ${_health!['model']}';
      statusIcon = Icons.check_circle;
    }

    return Card(
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor),
        title: Text('Trạng thái máy chủ', style: theme.textTheme.titleSmall),
        subtitle: Text(statusText),
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            _retryCount = 0;
            setState(() => _healthLoading = true);
            _checkHealth();
          },
        ),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            children: [
              Icon(Icons.mic_none, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Chưa có bản ghi nào',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              const Text('Nhấn nút Ghi âm để bắt đầu'),
            ],
          ),
        ),
      );

  Widget _recordingTile(
    BuildContext context,
    Map<String, dynamic> r,
    ThemeData theme,
  ) {
    final date = r['date'] as DateTime;
    final transcript = r['transcript'] as Map<String, dynamic>;
    final text = (transcript['text'] ?? '').toString();
    final preview = text.length > 60 ? '${text.substring(0, 60)}...' : text;
    final duration = transcript['duration'];

    return Card(
      child: ListTile(
        leading: const Icon(Icons.audio_file, color: Colors.indigo),
        title: Text(
          preview.isEmpty ? '(bản ghi trống)' : preview,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${date.day}/${date.month}/${date.hour}:${date.minute.toString().padLeft(2, '0')}'
          '${duration != null ? ' · ${duration}s' : ''}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => widget.onOpenResult(r),
      ),
    );
  }
}
