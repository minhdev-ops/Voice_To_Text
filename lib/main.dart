import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'api_service.dart';
import 'result_view.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Auvira - Voice To Text',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _baseUrl = TextEditingController(text: 'http://127.0.0.1:8000');
  final _language = TextEditingController(text: 'vi');
  final _audioRecorder = AudioRecorder();

  List<String> _models = const ['tiny', 'base', 'small', 'medium', 'large-v3'];
  String _model = 'base';
  bool _loading = false;
  bool _recording = false;
  String? _error;
  Map<String, dynamic>? _transcript;
  Map<String, dynamic>? _summary;

  ApiService get api => ApiService(_baseUrl.text.trim());

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    try {
      final m = await api.listModels();
      if (m.isNotEmpty) setState(() => _models = m);
    } catch (_) {}
  }

  Future<void> _process(List<int> bytes, String filename) async {
    setState(() {
      _loading = true;
      _error = null;
      _transcript = null;
      _summary = null;
    });
    try {
      final lang = _language.text.trim().isEmpty ? null : _language.text.trim();
      final res = await api.transcribeAudio(bytes, filename,
          language: lang, model: _model);
      setState(() {
        _transcript = res['transcript'] as Map<String, dynamic>;
        _summary = res['summary'] as Map<String, dynamic>;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (res != null && res.files.single.bytes != null) {
      await _process(res.files.single.bytes!, res.files.single.name);
    }
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      final path = await _audioRecorder.stop();
      setState(() => _recording = false);
      if (path != null) {
        final bytes = await File(path).readAsBytes();
        await _process(bytes.toList(), 'recording.m4a');
      }
    } else {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => _recording = true);
      } else {
        setState(() => _error = 'Chưa được cấp quyền ghi âm (microphone).');
      }
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _baseUrl.dispose();
    _language.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Auvira — Voice To Text')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _settingsCard(),
                    const SizedBox(height: 16),
                    if (_error != null) _errorCard(),
                    if (_transcript != null && _summary != null)
                      ResultView(transcript: _transcript!, summary: _summary!)
                    else
                      _actionCard(),
                  ],
                ),
              ),
      );

  Widget _settingsCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _baseUrl,
                decoration: const InputDecoration(
                  labelText: 'Backend URL',
                  hintText: 'http://127.0.0.1:8000',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _language,
                decoration: const InputDecoration(
                  labelText: 'Ngôn ngữ (vi/en, để trống = tự nhận)',
                  hintText: 'vi',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _model,
                items: _models
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => _model = v!),
                decoration:
                    const InputDecoration(labelText: 'Mô hình Whisper'),
              ),
            ],
          ),
        ),
      );

  Widget _errorCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );

  Widget _actionCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                  'Ghi âm cuộc họp hoặc tải lên file âm thanh để chép lời & tóm tắt.'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _toggleRecord,
                      icon: Icon(_recording ? Icons.stop : Icons.mic),
                      label: Text(_recording ? 'Dừng ghi âm' : 'Ghi âm'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Tải file'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
