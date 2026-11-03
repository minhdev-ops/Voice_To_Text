import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../api_service.dart';
import '../data/recording.dart';

class ResultScreen extends StatefulWidget {
  /// Xem lai mot ban ghi da luu.
  final Recording? recording;

  /// Hoac nhan dang mot tep moi.
  final ApiService? api;
  final List<int>? bytes;
  final String? filename;
  final String? language;
  final String? model;
  final Future<Recording?> Function(Map<String, dynamic>)? onCompleted;

  const ResultScreen({super.key, required this.recording})
      : api = null,
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
  }) : recording = null;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Recording? _rec;
  String? _error;
  bool _loading = false;

  AudioPlayer? _player;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _audioDuration = Duration.zero;
  double _speed = 1.0;
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _rec = widget.recording;
    if (_rec == null) {
      _load();
    } else {
      _initPlayer();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await widget.api!.transcribeAudio(
        widget.bytes!,
        widget.filename!,
        language: widget.language,
        model: widget.model,
      );
      final saved = await widget.onCompleted?.call(result);
      final t = (result['transcript'] as Map?) ?? const {};
      setState(() {
        _rec = saved ??
            Recording(
              title: Recording.suggestTitle((t['text'] ?? '').toString()),
              createdAt: DateTime.now(),
              duration: (t['duration'] as num?)?.toDouble(),
              model: t['model'] as String?,
              language: t['language'] as String?,
              transcript: (t['text'] ?? '').toString(),
              segments: (t['segments'] as List?) ?? const [],
              summary: (result['summary'] as Map?)?.cast<String, dynamic>() ??
                  const {},
            );
        _loading = false;
      });
      await _initPlayer();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _initPlayer() async {
    final path = _rec?.audioPath;
    if (path == null || !File(path).existsSync()) return;
    final p = AudioPlayer();
    _player = p;
    try {
      await p.setFilePath(path);
      _subs.add(p.positionStream.listen((pos) {
        if (mounted) setState(() => _position = pos);
      }));
      _subs.add(p.durationStream.listen((d) {
        if (mounted && d != null) setState(() => _audioDuration = d);
      }));
      _subs.add(p.playerStateStream.listen((s) {
        if (mounted) {
          setState(() => _playing = s.playing);
          if (s.processingState == ProcessingState.completed) {
            p.seek(Duration.zero);
            p.pause();
          }
        }
      }));
      if (mounted) setState(() {});
    } catch (_) {
      _player = null;
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player?.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rec = _rec;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          rec?.title ?? 'Kết quả',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (rec != null)
            IconButton(
              icon: const Icon(Icons.copy_all),
              tooltip: 'Sao chép bản chép lời',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: rec.transcript));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép bản chép lời')),
                );
              },
            ),
        ],
        bottom: rec != null
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
          ? _loadingView()
          : _error != null
              ? _errorView()
              : rec == null
                  ? const SizedBox()
                  : Column(
                      children: [
                        if (_player != null) _playerBar(),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _transcriptTab(rec),
                              _summaryTab(rec),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _loadingView() => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(strokeWidth: 4),
            ),
            SizedBox(height: 24),
            Text('Đang nhận dạng giọng nói...'),
            SizedBox(height: 8),
            Text('Vui lòng đợi trong giây lát.',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );

  Widget _errorView() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text('Có lỗi xảy ra', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_error ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 24),
            if (widget.api != null)
              FilledButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _loading = true;
                  });
                  _load();
                },
                child: const Text('Thử lại'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _playerBar() {
    final theme = Theme.of(context);
    final total = _audioDuration.inMilliseconds == 0
        ? (_rec?.duration ?? 0) * 1000
        : _audioDuration.inMilliseconds.toDouble();
    final value = _position.inMilliseconds.clamp(0, total).toDouble();
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton.filledTonal(
              onPressed: () {
                if (_playing) {
                  _player!.pause();
                } else {
                  _player!.play();
                }
              },
              icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
            ),
            Expanded(
              child: Slider(
                value: value.clamp(0, total == 0 ? 1 : total),
                max: total == 0 ? 1 : total,
                onChanged: (v) =>
                    _player!.seek(Duration(milliseconds: v.round())),
              ),
            ),
            Text(
              '${_fmt(_position)} / ${_fmt(Duration(milliseconds: total.round()))}',
              style: theme.textTheme.labelSmall,
            ),
            PopupMenuButton<double>(
              tooltip: 'Tốc độ phát',
              initialValue: _speed,
              onSelected: (v) {
                _player!.setSpeed(v);
                setState(() => _speed = v);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 0.75, child: Text('0.75×')),
                PopupMenuItem(value: 1.0, child: Text('1×')),
                PopupMenuItem(value: 1.25, child: Text('1.25×')),
                PopupMenuItem(value: 1.5, child: Text('1.5×')),
                PopupMenuItem(value: 2.0, child: Text('2×')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Text('$_speed×'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _transcriptTab(Recording rec) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                if (rec.language != null) _chip(Icons.language, rec.language!),
                if (rec.duration != null)
                  _chip(Icons.timer, '${rec.duration!.round()}s'),
                if (rec.model != null) _chip(Icons.memory, rec.model!),
                _chip(Icons.notes, '${rec.transcript.split(' ').length} từ'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (rec.segments.isNotEmpty)
          ...rec.segments.map((s) {
            final seg = s as Map;
            final start = (seg['start'] as num?)?.toDouble() ?? 0;
            final text = (seg['text'] ?? '').toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: _player == null
                        ? null
                        : () => _player!
                            .seek(Duration(milliseconds: (start * 1000).round())),
                    child: SizedBox(
                      width: 74,
                      child: Text(
                        _fmt(Duration(milliseconds: (start * 1000).round())),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SelectableText(text,
                        style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            );
          })
        else
          SelectableText(rec.transcript, style: theme.textTheme.bodyLarge),
      ],
    );
  }

  Widget _summaryTab(Recording rec) {
    final theme = Theme.of(context);
    final s = rec.summary;
    final summaryText = (s['summary'] ?? '').toString();
    final topics = (s['topics'] as List?) ?? [];
    final decisions = (s['decisions'] as List?) ?? [];
    final actions = (s['action_items'] as List?) ?? [];
    final questions = (s['open_questions'] as List?) ?? [];

    if (summaryText.isEmpty &&
        topics.isEmpty &&
        decisions.isEmpty &&
        actions.isEmpty &&
        questions.isEmpty) {
      return Center(
        child: Text('Chưa có tóm tắt cho bản ghi này',
            style: TextStyle(color: theme.colorScheme.outline)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (summaryText.isNotEmpty)
          _section(theme, 'Tóm tắt chung', Icons.description,
              [Text(summaryText)]),
        if (topics.isNotEmpty)
          _section(theme, 'Chủ đề chính', Icons.topic, [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: topics
                  .map((t) => Chip(
                        label: Text(t.toString()),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ]),
        if (decisions.isNotEmpty)
          _section(theme, 'Quyết định đã thống nhất', Icons.gavel, [
            ...decisions.map((d) => ListTile(
                  leading: const Icon(Icons.check_circle,
                      color: Colors.green, size: 20),
                  title: Text(d.toString()),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                )),
          ]),
        if (actions.isNotEmpty)
          _section(theme, 'Việc cần làm', Icons.task_alt, [
            ...actions.map((a) {
              final m = a as Map;
              final owner = m['owner'];
              final due = m['due'];
              return ListTile(
                leading: const Icon(Icons.radio_button_unchecked, size: 20),
                title: Text((m['task'] ?? '').toString()),
                subtitle: owner != null || due != null
                    ? Text([
                        if (owner != null) 'Phụ trách: $owner',
                        if (due != null) 'Hạn: $due',
                      ].join(' · '))
                    : null,
                contentPadding: EdgeInsets.zero,
                dense: true,
              );
            }),
          ]),
        if (questions.isNotEmpty)
          _section(theme, 'Câu hỏi / vướng mắc', Icons.help_outline, [
            ...questions.map((q) => ListTile(
                  leading: const Icon(Icons.help, color: Colors.orange, size: 20),
                  title: Text(q.toString()),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                )),
          ]),
      ],
    );
  }

  Widget _section(
    ThemeData theme,
    String title,
    IconData icon,
    List<Widget> children,
  ) =>
      Card(
        margin: const EdgeInsets.only(bottom: 12),
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
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );

  Widget _chip(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      );

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
