import 'dart:convert';

/// Mot ban ghi am + ket qua nhan dang, luu ben vung trong SQLite.
class Recording {
  final int? id;
  final String title;
  final DateTime createdAt;
  final double? duration;
  final String? model;
  final String? language;
  final String? audioPath;
  final String transcript;
  final List<dynamic> segments;
  final Map<String, String> speakers;
  final Map<String, List<String>> translations;
  final bool diarized;
  final Map<String, dynamic> summary;

  const Recording({
    this.id,
    required this.title,
    required this.createdAt,
    this.duration,
    this.model,
    this.language,
    this.audioPath,
    required this.transcript,
    this.segments = const [],
    this.speakers = const {},
    this.translations = const {},
    this.diarized = false,
    required this.summary,
  });

  factory Recording.fromResult(
    Map<String, dynamic> result, {
    required String title,
    String? audioPath,
  }) {
    final t = (result['transcript'] as Map?) ?? const {};
    final segs = (t['segments'] as List?) ?? const [];
    final diar = t['diarization'] as Map?;
    final isDiarized = (diar != null && (diar['num_speakers'] ?? 0) > 0) ||
        segs.any((x) => (x as Map?)?['speaker'] != null);
    return Recording(
      title: title,
      createdAt: DateTime.now(),
      duration: (t['duration'] as num?)?.toDouble(),
      model: t['model'] as String?,
      language: t['language'] as String?,
      audioPath: audioPath,
      transcript: (t['text'] ?? '').toString(),
      segments: segs,
      speakers: const {},
      diarized: isDiarized,
      summary: (result['summary'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  factory Recording.fromMap(Map<String, dynamic> m) => Recording(
        id: m['id'] as int?,
        title: (m['title'] ?? '') as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        duration: (m['duration'] as num?)?.toDouble(),
        model: m['model'] as String?,
        language: m['language'] as String?,
        audioPath: m['audio_path'] as String?,
        transcript: (m['transcript'] ?? '') as String,
        segments: _decodeList(m['segments_json']),
        speakers: _decodeStrMap(m['speakers_json']),
        translations: _decodeStrListMap(m['translations_json']),
        diarized: (m['diarized'] as int? ?? 0) == 1,
        summary: _decodeMap(m['summary_json']),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'created_at': createdAt.millisecondsSinceEpoch,
        'duration': duration,
        'model': model,
        'language': language,
        'audio_path': audioPath,
        'transcript': transcript,
        'segments_json': jsonEncode(segments),
        'speakers_json': jsonEncode(speakers),
        'translations_json': jsonEncode(translations),
        'diarized': diarized ? 1 : 0,
        'summary_json': jsonEncode(summary),
      };

  Recording copyWith({
    int? id,
    String? title,
    String? audioPath,
    String? transcript,
    List<dynamic>? segments,
    Map<String, String>? speakers,
    Map<String, List<String>>? translations,
    bool? diarized,
    Map<String, dynamic>? summary,
  }) => Recording(
        id: id ?? this.id,
        title: title ?? this.title,
        createdAt: createdAt,
        duration: duration,
        model: model,
        language: language,
        audioPath: audioPath ?? this.audioPath,
        transcript: transcript ?? this.transcript,
        segments: segments ?? this.segments,
        speakers: speakers ?? this.speakers,
        translations: translations ?? this.translations,
        diarized: diarized ?? this.diarized,
        summary: summary ?? this.summary,
      );

  /// Tieu de goi y tu noi dung transcript (giong cach app ghi chu dat ten).
  static String suggestTitle(String transcript, {DateTime? at}) {
    final cleaned = transcript.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) {
      final d = at ?? DateTime.now();
      return 'Ban ghi ${d.day}/${d.month} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    }
    final words = cleaned.split(' ').take(8).join(' ');
    final title = words.length > 60 ? words.substring(0, 60) : words;
    return title.replaceAll(RegExp(r'[.,;:!?]+$'), '');
  }

  static List<dynamic> _decodeList(dynamic raw) {
    if (raw is! String || raw.isEmpty) return const [];
    try {
      final v = jsonDecode(raw);
      return v is List ? v : const [];
    } catch (_) {
      return const [];
    }
  }

  static Map<String, dynamic> _decodeMap(dynamic raw) {
    if (raw is! String || raw.isEmpty) return const {};
    try {
      final v = jsonDecode(raw);
      return v is Map ? v.cast<String, dynamic>() : const {};
    } catch (_) {
      return const {};
    }
  }

  static Map<String, String> _decodeStrMap(dynamic raw) {
    final m = _decodeMap(raw);
    return m.map((k, v) => MapEntry(k, v.toString()));
  }

  static Map<String, List<String>> _decodeStrListMap(dynamic raw) {
    final m = _decodeMap(raw);
    return m.map((k, v) => MapEntry(
          k,
          v is List ? v.map((e) => e.toString()).toList() : <String>[],
        ));
  }
}
