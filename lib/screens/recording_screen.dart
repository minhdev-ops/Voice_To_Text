import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../api_service.dart';
import '../data/recording.dart';

/// Ghi am ra file WAV 16 kHz mono do he dieu hanh tao header (chuan cho Whisper).
const int _kSampleRate = 16000;

class RecordingScreen extends StatefulWidget {
  final AudioRecorder audioRecorder;
  final ApiService api;
  final String language;
  final String model;
  final Future<Recording?> Function(Map<String, dynamic>) onCompleted;

  const RecordingScreen({
    super.key,
    required this.audioRecorder,
    required this.api,
    required this.language,
    required this.model,
    required this.onCompleted,
  });

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  bool _recording = false;
  bool _paused = false;
  bool _processing = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  String? _error;
  StreamSubscription<Amplitude>? _ampSub;
  double _amp = -60;

  @override
  void dispose() {
    _timer?.cancel();
    _ampSub?.cancel();
    super.dispose();
  }

  Future<void> _toggleRecord() async {
    if (_recording && !_paused) {
      _timer?.cancel();
      setState(() => _paused = true);
      await widget.audioRecorder.pause();
      return;
    }
    if (_paused) {
      await widget.audioRecorder.resume();
      setState(() => _paused = false);
      _startTimer();
      return;
    }
    await _start();
  }

  Future<void> _start() async {
    if (!await widget.audioRecorder.hasPermission()) {
      setState(() => _error = 'Chưa được cấp quyền ghi âm (microphone).');
      return;
    }
    final dir = await getTemporaryDirectory();
    try {
      await widget.audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: _kSampleRate,
          numChannels: 1,
        ),
        path: '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav',
      );
    } catch (e) {
      setState(() => _error = 'Không bật được micro: $e');
      return;
    }
    _listenAmplitude();
    setState(() {
      _recording = true;
      _paused = false;
      _error = null;
      _elapsed = Duration.zero;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  void _listenAmplitude() {
    _ampSub?.cancel();
    _ampSub = widget.audioRecorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((amp) {
      if (mounted) setState(() => _amp = amp.current);
    });
  }

  Future<void> _stopAndProcess() async {
    _timer?.cancel();
    _ampSub?.cancel();
    setState(() {
      _recording = false;
      _paused = false;
      _processing = true;
    });

    try {
      final tempPath = await widget.audioRecorder.stop();
      if (tempPath == null) {
        throw Exception('Không lưu được file ghi âm');
      }
      final file = File(tempPath);
      if (!file.existsSync() || await file.length() < 2048) {
        throw Exception('Bản ghi quá ngắn hoặc không có âm thanh');
      }
      final audioPath = await _persist(tempPath);
      final bytes = await File(audioPath).readAsBytes();
      final result = await widget.api.transcribeAudio(
        bytes.toList(),
        p.basename(audioPath),
        language: widget.language,
        model: widget.model,
      );
      final text = ((result['transcript'] as Map?)?['text'] ?? '')
          .toString()
          .trim();
      if (text.isEmpty) {
        if (mounted) {
          setState(() {
            _processing = false;
            _error =
                'Không nhận ra được tiếng nói trong bản ghi này. Hãy thử nói to hơn, gần micro hơn.';
          });
        }
        return;
      }
      result['_audio_path'] = audioPath;
      await widget.onCompleted(result);
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        setState(() {
          _processing = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<String> _persist(String tempPath) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'recordings'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final name =
        'rec_${DateTime.now().millisecondsSinceEpoch}${p.extension(tempPath)}';
    final saved = await File(tempPath).copy(p.join(dir.path, name));
    return saved.path;
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_recording
            ? (_paused ? 'Tạm dừng' : 'Đang ghi...')
            : (_processing ? 'Đang xử lý...' : 'Ghi âm')),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _timer?.cancel();
            _ampSub?.cancel();
            widget.audioRecorder.stop();
            Navigator.pop(context);
          },
        ),
      ),
      body: _processing ? _processingView(theme) : _recordView(theme),
    );
  }

  Widget _recordView(ThemeData theme) {
    final isRecording = _recording && !_paused;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          const Spacer(),
          Text(
            _fmt(_elapsed),
            style: theme.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w300,
              color: isRecording ? Colors.red : theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _recording
                ? (_paused ? 'Đã tạm dừng' : 'Đang ghi âm...')
                : 'Sẵn sàng ghi âm',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _recording ? Colors.red : theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 18),
          _amplitudeMeter(),
          const SizedBox(height: 8),
          Text(
            _amp > -55 ? 'Đang nhận âm thanh' : 'Âm lượng rất nhỏ — hãy nói gần micro',
            style: theme.textTheme.labelSmall?.copyWith(
              color: _amp > -55 ? Colors.green : Colors.orange,
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                width: 56,
                child: _recording
                    ? IconButton.filledTonal(
                        onPressed: _toggleRecord,
                        icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                        iconSize: 26,
                        tooltip: _paused ? 'Tiếp tục' : 'Tạm dừng',
                      )
                    : null,
              ),
              GestureDetector(
                onTap: _recording ? _stopAndProcess : _toggleRecord,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        _recording ? Colors.red : theme.colorScheme.primary,
                  ),
                  child: Icon(
                    _recording ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  _recording ? 'Kết thúc' : '',
                  style: theme.textTheme.labelSmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _amplitudeMeter() {
    const bars = 24;
    final normalized = ((_amp + 60) / 60).clamp(0.0, 1.0);
    final active = (normalized * bars).round().clamp(0, bars);
    return SizedBox(
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(bars, (i) {
          final ratio = i / bars;
          final color = ratio < 0.6
              ? Colors.green
              : ratio < 0.85
                  ? Colors.amber
                  : Colors.red;
          return Container(
            width: 6,
            height: 12.0 + ratio * 28,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: i < active ? color : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }

  Widget _processingView(ThemeData theme) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(strokeWidth: 4),
            ),
            const SizedBox(height: 24),
            Text('Đang nhận dạng giọng nói...',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Mô hình: ${widget.model}',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('Vui lòng đợi, quá trình này có thể mất vài giây.',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
}
