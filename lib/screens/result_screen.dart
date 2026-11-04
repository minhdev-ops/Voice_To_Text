import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../api_service.dart';
import '../data/recording.dart';
import '../export/exporter.dart';
import 'speakers_screen.dart';

/// Wrapper tien loi cho man hinh ket qua tu tep ben ngoai (UI-03).
class ResultLoadRoute extends StatelessWidget {
  final ApiService api;
  final String filePath;
  final String filename;
  final String language;
  final String model;
  final bool diarize;
  final int? numSpeakers;
  final String audioPath;
  final Future<Recording?> Function(Map<String, dynamic>) onCompleted;

  const ResultLoadRoute({
    super.key,
    required this.api,
    required this.filePath,
    required this.filename,
    required this.language,
    required this.model,
    this.diarize = false,
    this.numSpeakers,
    required this.audioPath,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) => ResultScreen.loading(
        api: api,
        path: filePath,
        filename: filename,
        language: language,
        model: model,
        diarize: diarize,
        numSpeakers: numSpeakers,
        audioPath: audioPath,
        onCompleted: onCompleted,
      );
}

class ResultScreen extends StatefulWidget {
  final Recording? recording;
  final ApiService? api;
  final Future<void> Function(Recording, Map<String, dynamic>)? onSummaryUpdated;
  final Future<void> Function(Recording)? onEdited;

  final List<int>? bytes;
  final String? path;
  final String? filename;
  final String? language;
  final String? model;
  final bool diarize;
  final int? numSpeakers;
  final String? audioPath;
  final Future<Recording?> Function(Map<String, dynamic>)? onCompleted;

  const ResultScreen({
    super.key,
    required this.recording,
    this.api,
    this.onSummaryUpdated,
    this.onEdited,
  })  : bytes = null,
        path = null,
        filename = null,
        language = null,
        model = null,
        diarize = false,
        numSpeakers = null,
        audioPath = null,
        onCompleted = null;

  const ResultScreen.loading({
    super.key,
    required this.api,
    this.path,
    this.bytes,
    required this.filename,
    required this.language,
    required this.model,
    this.diarize = false,
    this.numSpeakers,
    this.audioPath,
    required this.onCompleted,
  })  : recording = null,
        onSummaryUpdated = null,
        onEdited = null;

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

  // --- che do sua (UI-05) ---
  bool _editing = false;
  List<dynamic> _editSegments = [];
  String _editText = '';
  final List<List<dynamic>> _undo = [];
  final List<List<dynamic>> _redo = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _rec = widget.recording;
    if (_rec == null) {
      _load();
    } else {
      _editText = _rec!.transcript;
      _editSegments = _rec!.segments.map((e) => Map.from(e)).toList();
      _initPlayer();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = widget.path != null
          ? await widget.api!.transcribeFile(
              widget.path!,
              widget.filename!,
              language: widget.language,
              model: widget.model,
              diarize: widget.diarize,
              numSpeakers: widget.numSpeakers,
            )
          : await widget.api!.transcribeAudio(
              widget.bytes!,
              widget.filename!,
              language: widget.language,
              model: widget.model,
            );
      result['_audio_path'] = widget.audioPath;
      final saved = await widget.onCompleted?.call(result);
      final t = (result['transcript'] as Map?) ?? const {};
      final segs = (t['segments'] as List?) ?? const [];
      final diar = t['diarization'] as Map?;
      final isDiar = (diar != null && (diar['num_speakers'] ?? 0) > 0) ||
          segs.any((x) => (x as Map?)?['speaker'] != null);
      setState(() {
        _rec = saved ??
            Recording(
              title: Recording.suggestTitle((t['text'] ?? '').toString()),
              createdAt: DateTime.now(),
              duration: (t['duration'] as num?)?.toDouble(),
              model: t['model'] as String?,
              language: t['language'] as String?,
              audioPath: widget.audioPath,
              transcript: (t['text'] ?? '').toString(),
              segments: segs,
              speakers: const {},
              diarized: isDiar,
              summary: (result['summary'] as Map?)?.cast<String, dynamic>() ??
                  const {},
            );
        _editText = _rec!.transcript;
        _editSegments = _rec!.segments.map((e) => Map.from(e)).toList();
        _loading = false;
      });
      await _initPlayer();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
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

  void _pushUndo() {
    _undo.add(_editSegments.map((e) => Map.from(e)).toList());
    if (_undo.length > 50) _undo.removeAt(0);
    _redo.clear();
  }

  void _enterEdit() {
    _pushUndo();
    setState(() {
      _editing = true;
      _editSegments = _rec!.segments.map((e) => Map.from(e)).toList();
    });
  }

  void _onSegChanged(int i, String v) {
    _editSegments[i]['text'] = v;
    _rebuildText();
  }

  void _rebuildText() {
    _editText = _editSegments
        .map((s) => (s['text'] ?? '').toString().trim())
        .where((t) => t.isNotEmpty)
        .join(' ');
  }

  Future<void> _saveEdits() async {
    _rebuildText();
    final updated = _rec!.copyWith(
      transcript: _editText,
      segments: _editSegments,
    );
    setState(() {
      _rec = updated;
      _editing = false;
    });
    await widget.onEdited?.call(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Đã lưu bản chép lời')));
  }

  void _findReplace() {
    final findCtrl = TextEditingController();
    final repCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tìm và thay thế'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: findCtrl,
              decoration: const InputDecoration(labelText: 'Từ cần tìm'),
            ),
            TextField(
              controller: repCtrl,
              decoration: const InputDecoration(labelText: 'Thay bằng'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final f = findCtrl.text;
              final r = repCtrl.text;
              if (f.isNotEmpty) {
                for (final s in _editSegments) {
                  s['text'] = (s['text'] ?? '')
                      .toString()
                      .replaceAll(f, r);
                }
                _rebuildText();
              }
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Thay thế'),
          ),
        ],
      ),
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
          if (rec != null) ...[
            IconButton(
              icon: const Icon(Icons.copy_all),
              tooltip: 'Sao chép bản chép lời',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: rec.transcript));
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Đã sao chép')));
              },
            ),
            PopupMenuButton<ExportFormat>(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Xuất và chia sẻ',
              onSelected: (fmt) => _export(rec, fmt),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: ExportFormat.pdf,
                  child: ListTile(
                    leading: Icon(Icons.picture_as_pdf),
                    title: Text('Xuất PDF'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: ExportFormat.docx,
                  child: ListTile(
                    leading: Icon(Icons.description),
                    title: Text('Xuất Word (.docx)'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: ExportFormat.txt,
                  child: ListTile(
                    leading: Icon(Icons.notes),
                    title: Text('Xuất văn bản (.txt)'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            if (rec.diarized || rec.segments.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.record_voice_over),
                tooltip: 'Quản lý người nói',
                onPressed: _openSpeakers,
              ),
            IconButton(
              icon: Icon(_editing ? Icons.save : Icons.edit),
              tooltip: _editing ? 'Lưu' : 'Sửa chép lời',
              onPressed: _editing ? _saveEdits : _enterEdit,
            ),
          ],
        ],
        bottom: rec != null
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.text_snippet), text: 'Chép lời'),
                  Tab(icon: Icon(Icons.summarize), text: 'Tóm tắt'),
                  Tab(icon: Icon(Icons.translate), text: 'Bản dịch'),
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
                        if (_editing)
                          _editToolbar()
                        else if (_player != null)
                          _playerBar(),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _transcriptTab(rec),
                              _summaryTab(rec),
                              _translateTab(rec),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _editToolbar() => Container(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Hoàn tác',
              onPressed: _undo.isEmpty
                  ? null
                  : () {
                      _redo.add(_editSegments.map((e) => Map.from(e)).toList());
                      final prev = _undo.removeLast();
                      setState(() {
                        _editSegments = prev;
                        _rebuildText();
                      });
                    },
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              tooltip: 'Làm lại',
              onPressed: _redo.isEmpty
                  ? null
                  : () {
                      _undo.add(_editSegments.map((e) => Map.from(e)).toList());
                      final next = _redo.removeLast();
                      setState(() {
                        _editSegments = next;
                        _rebuildText();
                      });
                    },
            ),
            TextButton.icon(
              icon: const Icon(Icons.find_replace),
              label: const Text('Tìm / thay'),
              onPressed: _findReplace,
            ),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                _editing = false;
                _undo.clear();
                _redo.clear();
              }),
              child: const Text('Hủy'),
            ),
          ],
        ),
      );

  Future<void> _openSpeakers() async {
    if (_rec == null || widget.api == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpeakersScreen(
          api: widget.api!,
          recording: _rec!,
        ),
      ),
    );
    if (result is Recording && mounted) {
      setState(() => _rec = result);
      await widget.onEdited?.call(result);
    }
  }

  Future<void> _export(Recording rec, ExportFormat fmt) async {
    try {
      await Exporter.share(rec, fmt);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Xuất thất bại: $e')));
    }
  }

  String _targetLang = 'en';
  bool _translating = false;

  Future<void> _translate(Recording rec) async {
    if (widget.api == null) return;
    final texts = rec.segments.isNotEmpty
        ? rec.segments
            .map((s) => ((s as Map)['text'] ?? '').toString())
            .toList()
        : <String>[rec.transcript];
    setState(() => _translating = true);
    final res = await widget.api!.translate(texts, _targetLang, source: rec.language);
    if (!mounted) return;
    setState(() => _translating = false);
    if (res == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Không dịch được. Kiểm tra kết nối backend.')));
      return;
    }
    final list = ((res['translations'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    if (list.isEmpty) {
      final err = (res['error'] ??
              'Không dịch được. Hãy cấu hình AI trong Cài đặt.')
          .toString();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    final merged = Map<String, List<String>>.from(rec.translations);
    merged[_targetLang] = list;
    final updated = rec.copyWith(translations: merged);
    setState(() => _rec = updated);
    await widget.onEdited?.call(updated);
  }

  bool _resummarizing = false;

  Future<void> _resummarize() async {
    final rec = _rec;
    if (rec == null || widget.api == null) return;
    setState(() => _resummarizing = true);
    final s = await widget.api!.resummarize(
      rec.transcript,
      language: rec.language,
    );
    if (!mounted) return;
    setState(() => _resummarizing = false);
    if (s == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Không tạo được tóm tắt. Kiểm tra kết nối backend.')));
      return;
    }
    final updated = rec.copyWith(summary: s);
    setState(() => _rec = updated);
    await widget.onSummaryUpdated?.call(updated, s);
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

  String _speakerName(String? spk, Map<String, String> names) {
    if (spk == null || spk.isEmpty) return '';
    return names[spk] ?? spk;
  }

  Widget _transcriptTab(Recording rec) {
    final theme = Theme.of(context);
    if (_editing) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Sửa từng đoạn, rồi nhấn Lưu.',
                style: TextStyle(color: Colors.grey)),
          ),
          ..._editSegments.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value as Map;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 64,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _fmt(Duration(
                            milliseconds: ((s['start'] as num?)?.toDouble() ?? 0) * 1000 ~/ 1)),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.primary),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: s['text'] ?? ''),
                      onChanged: (v) => _onSegChanged(i, v),
                      maxLines: null,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      );
    }

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
                if (rec.diarized)
                  _chip(Icons.record_voice_over, '${rec.speakers.length} người nói'),
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
            final spk = seg['speaker'] as String?;
            final conf = (seg['confidence'] as num?)?.toDouble() ?? 0;
            final low = conf < -1.0;
            final name = _speakerName(spk, rec.speakers);
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
                        _fmt(Duration(
                            milliseconds: (start * 1000).round())),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.primary),
                      ),
                    ),
                  ),
                  if (name.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 6, top: 2),
                      child: Chip(
                        label: Text(name),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SelectableText(text,
                              style: theme.textTheme.bodyMedium),
                        ),
                        if (low)
                          Tooltip(
                            message: 'Đoạn này nhận dạng chưa chắc chắn',
                            child: Icon(Icons.warning_amber_rounded,
                                size: 16, color: Colors.orange.shade400),
                          ),
                      ],
                    ),
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

    final isEmpty = summaryText.isEmpty &&
        topics.isEmpty &&
        decisions.isEmpty &&
        actions.isEmpty &&
        questions.isEmpty;

    if (isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.api != null) _aiButton(),
          const SizedBox(height: 32),
          Icon(Icons.auto_awesome_outlined,
              size: 56, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Text(
            'Chưa có tóm tắt cho bản ghi này',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.api != null) _aiButton(),
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

  static const _langs = <(String, String)>[
    ('en', 'English'),
    ('vi', 'Tiếng Việt'),
    ('zh', '中文'),
    ('ja', '日本語'),
    ('ko', '한국어'),
    ('fr', 'Français'),
    ('es', 'Español'),
    ('th', 'ไทย'),
  ];

  Widget _translateTab(Recording rec) {
    final theme = Theme.of(context);
    final current = rec.translations[_targetLang] ?? const <String>[];
    final segs = rec.segments;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('lang-$_targetLang'),
                    initialValue: _targetLang,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Dịch sang',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _langs
                        .map((l) => DropdownMenuItem(
                              value: l.$1,
                              child: Text(l.$2),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _targetLang = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _translating ? null : () => _translate(rec),
                  icon: _translating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.translate),
                  label: Text(_translating
                      ? 'Đang dịch...'
                      : (current.isEmpty ? 'Dịch' : 'Dịch lại')),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (current.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(Icons.translate, size: 56, color: theme.colorScheme.outlineVariant),
                const SizedBox(height: 12),
                Text(
                  'Chưa có bản dịch',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Chọn ngôn ngữ rồi nhấn Dịch.\nCần cấu hình AI trong Cài đặt để có chất lượng tốt nhất.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
          )
        else
          ...List.generate(current.length, (i) {
            final src = segs.isNotEmpty && i < segs.length
                ? ((segs[i] as Map)['text'] ?? '').toString()
                : (i == 0 ? rec.transcript : '');
            final start = segs.isNotEmpty && i < segs.length
                ? ((segs[i] as Map)['start'] as num?)?.toDouble() ?? 0
                : 0.0;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fmt(Duration(milliseconds: (start * 1000).round())),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      src,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const Divider(height: 14),
                    SelectableText(
                      current[i],
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _aiButton() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: FilledButton.tonalIcon(
          onPressed: _resummarizing ? null : _resummarize,
          icon: _resummarizing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(_resummarizing
              ? 'Đang tóm tắt bằng AI...'
              : 'Tạo lại tóm tắt bằng AI'),
        ),
      );

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
