import 'package:flutter/material.dart';
import '../api_service.dart';

class ResultScreen extends StatefulWidget {
  // ignore: prefer_initializing_formals
  final Map<String, dynamic>? transcript;
  // ignore: prefer_initializing_formals
  final Map<String, dynamic>? summary;
  final ApiService? api;
  final List<int>? bytes;
  final String? filename;
  final String? language;
  final String? model;
  final void Function(Map<String, dynamic>)? onCompleted;

  const ResultScreen({
    super.key,
    required this.transcript,
    required this.summary,
  })  : api = null,
        bytes = null,
        filename = null,
        language = null,
        model = null,
        onCompleted = null;

  const ResultScreen.loading({
    super.key,
    required this.api,
    required this.bytes,
    required this.filename,
    required this.language,
    required this.model,
    required this.onCompleted,
  })  : transcript = null,
        summary = null;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
  with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _transcript;
  Map<String, dynamic>? _summary;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.transcript != null) {
      _transcript = widget.transcript;
      _summary = widget.summary;
    } else {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final result = await widget.api!.transcribeAudio(
        widget.bytes!,
        widget.filename!,
        language: widget.language,
        model: widget.model,
      );
      setState(() {
        _transcript = result['transcript'] as Map<String, dynamic>;
        _summary = result['summary'] as Map<String, dynamic>;
        _loading = false;
      });
      widget.onCompleted?.call(result);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kết quả'),
        bottom: _transcript != null
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.text_snippet), text: 'Chép lời'),
                  Tab(icon: Icon(Icons.summarize), text: 'Tóm tắt'),
                ],
              )
            : null,
      ),
      body: _loading
          ? _loadingView(theme)
          : _error != null
              ? _errorView(theme)
              : _transcript != null && _summary != null
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _transcriptTab(theme),
                        _summaryTab(theme),
                      ],
                    )
                  : const SizedBox(),
    );
  }

  Widget _loadingView(ThemeData theme) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(strokeWidth: 4),
            ),
            const SizedBox(height: 24),
            Text('Đang nhận dạng giọng nói...',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Vui lòng đợi, quá trình này có thể mất vài giây.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );

  Widget _errorView(ThemeData theme) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text('Có lỗi xảy ra', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                _error ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 24),
              if (widget.api != null)
                FilledButton(
                  onPressed: () {
                    setState(() { _error = null; _loading = false; });
                    _loadData();
                  },
                  child: const Text('Thử lại'),
                ),
            ],
          ),
        ),
      );

  Widget _transcriptTab(ThemeData theme) {
    final text = (_transcript!['text'] ?? '').toString();
    final segments = (_transcript!['segments'] as List?) ?? [];
    final lang = _transcript!['language'];
    final dur = _transcript!['duration'];
    final model = _transcript!['model'];
    final device = _transcript!['device'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Metadata card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if (lang != null) _chip(Icons.language, 'Ngôn ngữ: $lang'),
                if (dur != null) _chip(Icons.timer, 'Thời lượng: ${dur}s'),
                if (model != null) _chip(Icons.memory, 'Mô hình: $model'),
                if (device != null) _chip(Icons.devices, 'Thiết bị: $device'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (segments.isNotEmpty) ...[
          Text('Nội dung theo đoạn', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...segments.map((s) {
            final seg = s as Map<String, dynamic>;
            final start = seg['start'];
            final end = seg['end'];
            final segText = (seg['text'] ?? '').toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      '${_fmtTime(start)} - ${_fmtTime(end)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SelectableText(segText,
                        style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            );
          }),
        ] else ...[
          SelectableText(text, style: theme.textTheme.bodyLarge),
        ],
      ],
    );
  }

  Widget _summaryTab(ThemeData theme) {
    final s = _summary!;
    final summaryText = (s['summary'] ?? '').toString();
    final topics = (s['topics'] as List?) ?? [];
    final decisions = (s['decisions'] as List?) ?? [];
    final actions = (s['action_items'] as List?) ?? [];
    final questions = (s['open_questions'] as List?) ?? [];
    final method = (s['method'] ?? '').toString();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (summaryText.isNotEmpty) ...[
          _sectionCard(theme, 'Tóm tắt chung', Icons.description, [
            Text(summaryText),
          ]),
          const SizedBox(height: 12),
        ],
        if (topics.isNotEmpty) ...[
          _sectionCard(theme, 'Chủ đề chính', Icons.topic, [
            Wrap(
              spacing: 8,
              children: topics.take(10).map<Widget>((t) {
                return Chip(
                  label: Text(t.toString()),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ]),
          const SizedBox(height: 12),
        ],
        if (decisions.isNotEmpty) ...[
          _sectionCard(theme, 'Quyết định đã thống nhất', Icons.gavel, [
            ...decisions.map((d) => ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  title: Text(d.toString()),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                )),
          ]),
          const SizedBox(height: 12),
        ],
        if (actions.isNotEmpty) ...[
          _sectionCard(theme, 'Việc cần làm', Icons.task_alt, [
            ...actions.map((a) {
              final m = a as Map;
              final task = (m['task'] ?? '').toString();
              final owner = m['owner'];
              final due = m['due'];
              return ListTile(
                leading: const Icon(Icons.radio_button_unchecked, size: 20),
                title: Text(task),
                subtitle: owner != null || due != null
                    ? Text([
                        if (owner != null) 'Người phụ trách: $owner',
                        if (due != null) 'Hạn: $due',
                      ].join(' · '))
                    : null,
                contentPadding: EdgeInsets.zero,
                dense: true,
              );
            }),
          ]),
          const SizedBox(height: 12),
        ],
        if (questions.isNotEmpty) ...[
          _sectionCard(theme, 'Câu hỏi / vướng mắc', Icons.help_outline, [
            ...questions.map((q) => ListTile(
                  leading: const Icon(Icons.help, color: Colors.orange, size: 20),
                  title: Text(q.toString()),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                )),
          ]),
          const SizedBox(height: 12),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            method.isNotEmpty ? 'Phương pháp: $method' : '',
            style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard(ThemeData theme, String title, IconData icon, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  String _fmtTime(dynamic t) {
    if (t == null) return '0:00';
    final s = (t as num).toDouble();
    final m = (s ~/ 60);
    final sec = (s % 60).toInt();
    return '$m:${sec.toString().padLeft(2, '0')}';
  }
}
