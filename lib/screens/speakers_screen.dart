import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../api_service.dart';
import '../data/recording.dart';

/// UI-07: Quan ly nguoi noi - doi ten, gop, gan lai, chay phan tich lai.
class SpeakersScreen extends StatefulWidget {
  final ApiService api;
  final Recording recording;

  const SpeakersScreen({
    super.key,
    required this.api,
    required this.recording,
  });

  @override
  State<SpeakersScreen> createState() => _SpeakersScreenState();
}

class _SpeakersScreenState extends State<SpeakersScreen> {
  late List<dynamic> _segments;
  late Map<String, String> _names;
  bool _diarized = false;
  bool _busy = false;
  int? _numSpeakers;
  String? _error;

  final _palette = const [
    Colors.indigo, Colors.teal, Colors.deepOrange, Colors.purple,
    Colors.brown, Colors.blueGrey, Colors.green, Colors.pink,
  ];

  @override
  void initState() {
    super.initState();
    _segments = widget.recording.segments.map((e) => Map.from(e)).toList();
    _names = Map<String, String>.from(widget.recording.speakers);
    _diarized = widget.recording.diarized;
    if (_names.isEmpty) _rebuildNames();
  }

  List<String> get _speakerIds {
    final ids = <String>{};
    for (final s in _segments) {
      final sp = (s as Map)['speaker'] as String?;
      if (sp != null && sp.isNotEmpty) ids.add(sp);
    }
    return ids.toList()..sort();
  }

  Color _colorFor(String id) {
    final idx = _speakerIds.indexOf(id);
    return _palette[idx % _palette.length];
  }

  void _rebuildNames() {
    for (final id in _speakerIds) {
      _names.putIfAbsent(id, () => 'Người nói ${_speakerIds.indexOf(id) + 1}');
    }
    // xoa ten cua nguoi noi khong con
    _names.removeWhere((k, _) => !_speakerIds.contains(k));
  }

  int _countFor(String id) =>
      _segments.where((s) => (s as Map)['speaker'] == id).length;

  Future<void> _runDiarize() async {
    if (widget.recording.audioPath == null) {
      setState(() => _error = 'Bản ghi này không có file âm thanh để phân tích.');
      return;
    }
    setState(() => _busy = true);
    final res = await widget.api.diarize(
      widget.recording.audioPath!,
      p.basename(widget.recording.audioPath!),
      _segments,
      numSpeakers: _numSpeakers,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (res == null) {
      setState(() => _error = 'Không chạy được phân tích người nói.');
      return;
    }
    final segs = (res['segments'] as List?) ?? [];
    if (segs.isNotEmpty) {
      _segments = segs.map((e) => Map.from(e)).toList();
      _diarized = true;
      _rebuildNames();
      setState(() {});
    }
  }

  void _rename(String id) {
    final ctrl = TextEditingController(text: _names[id]);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi tên người nói'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isNotEmpty) setState(() => _names[id] = v);
              Navigator.pop(ctx);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _merge(String fromId) {
    final targets = _speakerIds.where((x) => x != fromId).toList();
    if (targets.isEmpty) return;
    String? target = targets.first;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gộp vào người nói khác'),
        content: DropdownButtonFormField<String>(
          initialValue: target,
          items: targets
              .map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(_names[t] ?? t),
                  ))
              .toList(),
          onChanged: (v) => target = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              for (final s in _segments) {
                if ((s as Map)['speaker'] == fromId) s['speaker'] = target;
              }
              _names.remove(fromId);
              _rebuildNames();
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Gộp'),
          ),
        ],
      ),
    );
  }

  void _reassign(Map seg) {
    final ids = _speakerIds;
    String? chosen = seg['speaker'] as String?;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gán người nói'),
        content: DropdownButtonFormField<String?>(
          initialValue: chosen,
          items: [
            const DropdownMenuItem(value: null, child: Text('(chưa rõ)')),
            ...ids.map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(_names[t] ?? t),
                )),
          ],
          onChanged: (v) => chosen = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              seg['speaker'] = chosen;
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _save() {
    _rebuildNames();
    final updated = widget.recording.copyWith(
      segments: _segments,
      speakers: _names,
      diarized: _diarized,
    );
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ids = _speakerIds;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý người nói'),
        actions: [
          TextButton.icon(
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.save),
            label: const Text('Lưu'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chạy phân tích lại', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(
                    'Tự động gán nhãn người nói theo giọng (offline, không cần mạng ngoài).',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Số người nói (tùy chọn)',
                            isDense: true,
                          ),
                          onChanged: (v) =>
                              _numSpeakers = int.tryParse(v.trim()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _busy ? null : _runDiarize,
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_fix_high),
                        label: const Text('Phân tích'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Danh sách người nói (${ids.length})',
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (ids.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Chưa có người nói nào. Hãy chạy phân tích.'),
            )
          else
            ...ids.map((id) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _colorFor(id),
                      child: Text('${_speakerIds.indexOf(id) + 1}'),
                    ),
                    title: Text(_names[id] ?? id),
                    subtitle: Text('${_countFor(id)} đoạn'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Đổi tên',
                          onPressed: () => _rename(id),
                        ),
                        IconButton(
                          icon: const Icon(Icons.merge),
                          tooltip: 'Gộp',
                          onPressed: () => _merge(id),
                        ),
                      ],
                    ),
                  ),
                )),
          const SizedBox(height: 16),
          Text('Từng đoạn', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          ..._segments.map((s) {
            final seg = s as Map;
            final spk = seg['speaker'] as String?;
            return InkWell(
              onTap: () => _reassign(seg),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (spk != null && spk.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8, top: 2),
                        child: Chip(
                          label: Text(_names[spk] ?? spk),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          backgroundColor:
                              _colorFor(spk).withValues(alpha: 0.15),
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(right: 8, top: 2),
                        child: Chip(
                          label: Text('?'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        (seg['text'] ?? '').toString(),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}
