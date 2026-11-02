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
  }) async {
    final uri = Uri.parse('$baseUrl/api/transcribe');
    final request = http.MultipartRequest('POST', uri);
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

    final streamed = await request.send().timeout(
      const Duration(seconds: 120),
      onTimeout: () => throw TimeoutException('Het thoi gian cho backend'),
    );
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode != 200) {
      throw Exception('Loi ${resp.statusCode}: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
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
