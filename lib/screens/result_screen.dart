import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../api_service.dart';
import '../data/recording.dart';

class ResultScreen extends StatefulWidget {
  final Recording? recording;
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
    _tabController = TabController(length: 3, vsync: this);
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

  void _copyAll() {
    final rec = _rec;
    if (rec == null) return;
    final buf = StringBuffer();
    buf.writeln('# $rec.title');
    buf.writeln();
    buf.writeln('## Bản chép lời');
    buf.writeln(rec.transcript);
    buf.writeln();
    final s = rec.summary;
    if (s.isNotEmpty) {
      buf.writeln('## Tóm tắt');
      if (s['summary'] != null) {
        buf.writeln();
        buf.writeln(s['summary'].toString());
      }
      final topics = s['topics'] as List?;
      if (topics != null && topics.isNotEmpty) {
        buf.writeln();
        buf.writeln('### Chủ đề');
        for (final t in topics) {
          buf.writeln('- ${t.toString()}');
        }
      }
      final decisions = s['decisions'] as List?;
      if (decisions != null && decisions.isNotEmpty) {
        buf.writeln();
        buf.writeln('### Quyết định');
        for (final d in decisions) {
          buf.writeln('- ${d.toString()}');
        }
      }
      final actions = s['action_items'] as List?;
      if (actions != null && actions.isNotEmpty) {
        buf.writeln();
        buf.writeln('### Việc cần làm');
        for (final a in actions) {
          if (a is Map) {
            buf.writeln('- ${(a['task'] ?? '').toString()}');
            if (a['owner'] != null) buf.writeln('  Phụ trách: ${a['owner'].toString()}');
            if (a['due'] != null) buf.writeln('  Hạn: ${a['due'].toString()}');
          } else {
            buf.writeln('- ${a.toString()}');
          }
        }
      }
      final questions = s['open_questions'] as List?;
      if (questions != null && questions.isNotEmpty) {
        buf.writeln();
        buf.writeln('### Câu hỏi');
        for (final q in questions) {
          buf.writeln('- ${q.toString()}');
        }
      }
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã sao chép toàn bộ nội dung')),
    );
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
              tooltip: 'Sao chép',
              onPressed: _copyAll,
            ),
          if (rec != null)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Chia sẻ',
              onPressed: _copyAll,
            ),
        ],
        bottom: rec != null
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.text_snippet), text: 'Chép lời'),
                  Tab(icon: Icon(Icons.summarize), text: 'Tóm tắt'),
                  Tab(icon: Icon(Icons.account_tree), text: 'Sơ đồ'),
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
                              _mindMapTab(rec),
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
                child: Text('${_speed.toString()}×'),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.summarize, size: 64, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text('Chưa có tóm tắt', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              'Tóm tắt sẽ được tạo tự động sau khi nhận dạng.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (summaryText.isNotEmpty)
          _section(theme, 'Tóm tắt chung', Icons.description,
              [SelectableText(summaryText)]),
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
              final m = a is Map ? a : {'task': a.toString()};
              final owner = m['owner'];
              final due = m['due'];
              return ListTile(
                leading: const Icon(Icons.radio_button_unchecked, size: 20),
                title: Text((m['task'] ?? '').toString()),
                subtitle: owner != null || due != null
                    ? Text([
                        if (owner != null) 'Phụ trách: ${owner.toString()}',
                        if (due != null) 'Hạn: ${due.toString()}',
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

  Widget _mindMapTab(Recording rec) {
    final theme = Theme.of(context);
    final s = rec.summary;
    final mindMap = s['mind_map'] as Map?;
    final flashcards = (s['flashcards'] as List?) ?? [];

    if (mindMap == null || mindMap.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_tree, size: 64, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text('Chưa có sơ đồ tư duy', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              'Sơ đồ tư duy sẽ được tạo khi có tóm tắt từ LLM.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final root = (mindMap['root'] ?? 'Cuộc họp').toString();
    final branches = (mindMap['branches'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Mind map root
        Center(
          child: Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text(
                root,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Branches
        ...branches.map((b) {
          final branch = b as Map;
          final label = (branch['label'] ?? '').toString();
          final children = (branch['children'] as List?) ?? [];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.secondaryContainer,
                child: Icon(Icons.topic,
                    color: theme.colorScheme.onSecondaryContainer, size: 20),
              ),
              title: Text(label, style: theme.textTheme.titleSmall),
              children: children.map((c) {
                return ListTile(
                  leading: const Icon(Icons.subdirectory_arrow_right, size: 16),
                  title: Text(c.toString()),
                  dense: true,
                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                );
              }).toList(),
            ),
          );
        }),
        // Flashcards section
        if (flashcards.isNotEmpty) ...[
          const SizedBox(height: 24),
          _section(theme, 'Thẻ ghi nhớ', Icons.style, [
            ...flashcards.map((f) {
              final card = f as Map;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.tertiaryContainer,
                    child: Icon(Icons.quiz,
                        color: theme.colorScheme.onTertiaryContainer, size: 20),
                  ),
                  title: Text((card['q'] ?? '').toString(),
                      style: theme.textTheme.bodyMedium),
                  children: [
                    ListTile(
                      title: Text((card['a'] ?? '').toString(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          )),
                      contentPadding: const EdgeInsets.only(left: 32, right: 16),
                    ),
                  ],
                ),
              );
            }),
          ]),
        ],
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
