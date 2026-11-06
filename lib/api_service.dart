import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Client goi backend Python (FastAPI) cua Voice_To_Text.
class ApiService {
  final String baseUrl;

  ApiService(this.baseUrl);

  Future<Map<String, dynamic>> transcribeAudio(
    List<int> bytes,
    String filename, {
    String? language,
    String? model,
    void Function(Map<String, dynamic> task)? onProgress,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/tasks'),
    );
    final ext = filename.split('.').last.toLowerCase();
    final mime = _mimeFor(ext);
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType(mime.$1, mime.$2),
      ),
    );
    if (language != null) request.fields['language'] = language;
    if (model != null) request.fields['model'] = model;
    return _awaitTask(await _submit(request), onProgress: onProgress);
  }

  Future<List<String>> listModels() async {
    try {
      final resp = await http.get(Uri.parse('$baseUrl/api/models'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<String>.from(data['models']);
      }
    } catch (_) {}
    return const ['tiny', 'base', 'small', 'medium', 'large-v3'];
  }

  Future<Map<String, dynamic>?> checkHealth() async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/health'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Nhan dang nhanh mot doan ngan (chep loi truc tiep). Tra ve text hoac null.
  Future<String?> transcribeChunk(
    List<int> wavBytes, {
    String? language,
    String model = 'small',
  }) async {
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/transcribe-chunk'),
      );
      req.files.add(http.MultipartFile.fromBytes(
        'file',
        wavBytes,
        filename: 'chunk.wav',
        contentType: MediaType('audio', 'wav'),
      ));
      if (language != null) req.fields['language'] = language;
      req.fields['model'] = model;
      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (data['text'] ?? '').toString();
      }
    } catch (_) {}
    return null;
  }

  /// Tao lai tom tat cho transcript da co (dung LLM neu backend da cau hinh).
  Future<Map<String, dynamic>?> resummarize(
    String text, {
    String? language,
  }) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$baseUrl/api/resummarize'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text, 'language': language}),
          )
          .timeout(const Duration(seconds: 120));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getSummarySettings() async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/settings/summary'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> setSummarySettings({
    String? apiKey,
    String? baseUrl,
    String? model,
  }) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$baseUrl/api/settings/summary'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'api_key': ?apiKey,
              'base_url': ?baseUrl,
              'model': ?model,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Nhan dang mot tep da co tren dia (UI-03). Khong can doc toan bo vao bo nho.
  Future<Map<String, dynamic>> transcribeFile(
    String path,
    String filename, {
    String? language,
    String? model,
    bool diarize = false,
    int? numSpeakers,
    void Function(Map<String, dynamic> task)? onProgress,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/tasks'),
    );
    final mime = _mimeFor(filename.split('.').last.toLowerCase());
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        path,
        filename: filename,
        contentType: MediaType(mime.$1, mime.$2),
      ),
    );
    if (language != null) request.fields['language'] = language;
    if (model != null) request.fields['model'] = model;
    request.fields['diarize'] = diarize ? 'true' : 'false';
    if (numSpeakers != null) request.fields['num_speakers'] = '$numSpeakers';
    return _awaitTask(await _submit(request), onProgress: onProgress);
  }

  /// Phan biet nguoi noi cho transcript da co (UI-07).
  Future<Map<String, dynamic>?> diarize(
    String path,
    String filename,
    List<dynamic> segments, {
    int? numSpeakers,
  }) async {
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/diarize'),
      );
      final dm = _mimeFor(filename.split('.').last.toLowerCase());
      req.files.add(
        await http.MultipartFile.fromPath(
          'file',
          path,
          filename: filename,
          contentType: MediaType(dm.$1, dm.$2),
        ),
      );
      req.fields['segments'] = jsonEncode(segments);
      if (numSpeakers != null) req.fields['num_speakers'] = '$numSpeakers';
      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Danh sach mo hinh + trang thai cai dat (UI-11).
  Future<Map<String, dynamic>?> modelsStatus() async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/models/status'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> modelDownload(String name) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$baseUrl/api/models/download'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'name': name}),
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> modelDelete(String name) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$baseUrl/api/models/delete'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'name': name}),
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> modelDownloadStatus() async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/models/download'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {}
    return null;
  }

  /// Dich danh sach doan sang ngon ngu dich (UI: tab Ban dich).
  Future<Map<String, dynamic>?> translate(
    List<String> texts,
    String target, {
    String? source,
  }) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$baseUrl/api/translate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'texts': texts, 'target': target, 'source': source}),
          )
          .timeout(const Duration(seconds: 180));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Danh sach ngon ngu dich ho tro.
  Future<List<Map<String, dynamic>>> languages() async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/languages'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final d = jsonDecode(resp.body) as Map<String, dynamic>;
        return (d['languages'] as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return const [
      {'code': 'en', 'name': 'English'},
      {'code': 'vi', 'name': 'Tiếng Việt'},
      {'code': 'zh', 'name': '中文'},
      {'code': 'ja', 'name': '日本語'},
      {'code': 'ko', 'name': '한국어'},
    ];
  }

  /// Gui file audio, nhan task_id. Backend xu ly nen (giong NoteX).
  Future<String> _submit(http.MultipartRequest request) async {
    final streamed = await request.send().timeout(
      const Duration(minutes: 10),
      onTimeout: () => throw TimeoutException('Het thoi gian tai file len backend'),
    );
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode != 200 && resp.statusCode != 202) {
      throw Exception('Loi ${resp.statusCode}: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final id = data['task_id'];
    if (id is! String) {
      throw Exception('Backend khong tra task_id: ${resp.body}');
    }
    return id;
  }

  /// Poll task: PENDING -> PROCESSING -> SUCCESS/FAILURE.
  Future<Map<String, dynamic>> _awaitTask(
    String taskId, {
    void Function(Map<String, dynamic> task)? onProgress,
  }) async {
    while (true) {
      await Future.delayed(const Duration(seconds: 2));
      final resp = await http
          .get(Uri.parse('$baseUrl/api/tasks/$taskId'))
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) {
        throw Exception('Loi ${resp.statusCode}: ${resp.body}');
      }
      final task = jsonDecode(resp.body) as Map<String, dynamic>;
      onProgress?.call(task);
      final status = task['status'];
      if (status == 'SUCCESS') {
        final data = task['data'];
        if (data is Map) return Map<String, dynamic>.from(data);
        throw Exception('Task khong co ket qua');
      }
      if (status == 'FAILURE' || status == 'FAIL') {
        throw Exception((task['error'] ?? 'Xu ly that bai').toString());
      }
    }
  }

  static (String, String) _mimeFor(String ext) {
    switch (ext) {
      case 'wav':
        return ('audio', 'wav');
      case 'mp3':
        return ('audio', 'mpeg');
      case 'm4a':
        return ('audio', 'mp4');
      case 'ogg':
        return ('audio', 'ogg');
      case 'flac':
        return ('audio', 'flac');
      case 'webm':
        return ('audio', 'webm');
      default:
        return ('application', 'octet-stream');
    }
  }
}
