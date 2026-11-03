import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import 'api_service.dart';
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
  String _language = 'vi';
  String _model = 'large-v3';
  final List<Map<String, dynamic>> _recordings = [];

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    final models = await _api.listModels();
    if (models.isNotEmpty && mounted) {
      setState(() {});
    }
  }

  void _addRecording(Map<String, dynamic> result) {
    setState(() {
      _recordings.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch,
        'date': DateTime.now(),
        'transcript': result['transcript'],
        'summary': result['summary'],
      });
    });
  }

  void _openResult(Map<String, dynamic> recording) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          transcript: recording['transcript'] as Map<String, dynamic>,
          summary: recording['summary'] as Map<String, dynamic>,
        ),
      ),
    );
  }

  Future<void> _startRecording() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecordingScreen(
          audioRecorder: _audioRecorder,
          api: _api,
          language: _language,
          model: _model,
          onCompleted: _addRecording,
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (res != null && res.files.single.bytes != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen.loading(
            api: _api,
            bytes: res.files.single.bytes!.toList(),
            filename: res.files.single.name,
            language: _language,
            model: _model,
            onCompleted: _addRecording,
          ),
        ),
      );
    }
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
            api: _api,
            onOpenResult: _openResult,
            onRecord: _startRecording,
            onPickFile: _pickFile,
          ),
          SearchScreen(recordings: _recordings, onOpenResult: _openResult),
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
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Tìm kiếm',
          ),
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
