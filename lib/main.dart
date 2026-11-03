import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import 'api_service.dart';
import 'data/recording.dart';
import 'data/recording_repository.dart';
import 'screens/home_screen.dart';
import 'screens/recording_screen.dart';
import 'screens/result_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';

void main() => runApp(const VietVoiceApp());

class VietVoiceApp extends StatelessWidget {
  const VietVoiceApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'VietVoice',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.indigo,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.indigo,
          brightness: Brightness.dark,
        ),
        themeMode: ThemeMode.system,
        home: const MainShell(),
        debugShowCheckedModeBanner: false,
      );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  String _baseUrl = 'http://127.0.0.1:8000';
  ApiService get _api => ApiService(_baseUrl);
  final _audioRecorder = AudioRecorder();
  final _repo = RecordingRepository();
  String _language = 'vi';
  String _model = 'large-v3';
  List<Recording> _recordings = [];
  bool _loadingList = true;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    try {
      final items = await _repo.all();
      if (mounted) setState(() { _recordings = items; _loadingList = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingList = false);
    }
  }

  /// Luu ket qua nhan dang xuong SQLite (ben vung qua cac lan mo app).
  Future<Recording?> _saveResult(Map<String, dynamic> result) async {
    final t = (result['transcript'] as Map?) ?? const {};
    final text = (t['text'] ?? '').toString();
    final title = (result['_title'] as String?) ??
        Recording.suggestTitle(text);
    final rec = Recording.fromResult(
      result,
      title: title,
      audioPath: result['_audio_path'] as String?,
    );
    try {
      final saved = await _repo.insert(rec);
      await _loadRecordings();
      return saved;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openResult(Recording rec) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ResultScreen(recording: rec)),
    );
    await _loadRecordings();
  }

  Future<void> _startRecording() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecordingScreen(
          audioRecorder: _audioRecorder,
          api: _api,
          language: _language,
          model: _model,
          onCompleted: _saveResult,
        ),
      ),
    );
    await _loadRecordings();
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (res == null || res.files.single.bytes == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen.loading(
          api: _api,
          bytes: res.files.single.bytes!.toList(),
          filename: res.files.single.name,
          language: _language,
          model: _model,
          onCompleted: _saveResult,
        ),
      ),
    );
    await _loadRecordings();
  }

  Future<void> _renameRecording(Recording rec, String title) async {
    if (rec.id == null) return;
    await _repo.rename(rec.id!, title);
    await _loadRecordings();
  }

  Future<void> _deleteRecording(Recording rec) async {
    if (rec.id == null) return;
    await _repo.delete(rec.id!);
    await _loadRecordings();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            recordings: _recordings,
            loading: _loadingList,
            api: _api,
            onOpenResult: _openResult,
            onRecord: _startRecording,
            onPickFile: _pickFile,
            onRename: _renameRecording,
            onDelete: _deleteRecording,
          ),
          SearchScreen(
            recordings: _recordings,
            onOpenResult: _openResult,
            onDelete: _deleteRecording,
          ),
          SettingsScreen(
            api: _api,
            baseUrl: _baseUrl,
            language: _language,
            model: _model,
            onBaseUrlChanged: (v) => setState(() => _baseUrl = v),
            onLanguageChanged: (v) => setState(() => _language = v),
            onModelChanged: (v) => setState(() => _model = v),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mic_none),
            selectedIcon: Icon(Icons.mic),
            label: 'Bản ghi',
          ),
          NavigationDestination(icon: Icon(Icons.search), label: 'Tìm kiếm'),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }
}
