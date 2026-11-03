import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../api_service.dart';
import '../data/recording.dart';

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
  String? _path;
  StreamSubscription<Amplitude>? _ampSub;
  double _amp = -60; // dBFS

  @override
  void dispose() {
    _timer?.cancel();
    _ampSub?.cancel();
    super.dispose();
  }

  void _listenAmplitude() {
    _ampSub?.cancel();
    _ampSub = widget.audioRecorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((amp) {
      if (mounted) setState(() => _amp = amp.current);
    });
  }

  Future<void> _toggleRecord() async {
    if (_recording && !_paused) {
      _timer?.cancel();
      setState(() => _paused = true);
      await widget.audioRecorder.pause();
    } else if (_paused) {
      await widget.audioRecorder.resume();
      setState(() => _paused = false);
      _startTimer();
    } else {
      if (await widget.audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        _path = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';
        const config = RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 256000,
        );
        await widget.audioRecorder.start(config, path: _path!);
        setState(() => _recording = true);
        _startTimer();
        _listenAmplitude();
      } else {
        setState(() => _error = 'Chưa được cấp quyền ghi âm (microphone).');
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _stopAndProcess() async {
    _timer?.cancel();
    _ampSub?.cancel();
    final path = await widget.audioRecorder.stop();
    setState(() {
      _recording = false;
      _paused = false;
      _processing = true;
    });

    if (path == null) {
      setState(() {
        _processing = false;
        _error = 'Không thể lưu file ghi âm.';
      });
      return;
    }

    try {
      // Luu file am thanh vao vung luu tru cua app de con nghe lai duoc.
      final docs = await getApplicationDocumentsDirectory();
      final audioDir = Directory(p.join(docs.path, 'recordings'));
      if (!audioDir.existsSync()) audioDir.createSync(recursive: true);
      final name =
          'rec_${DateTime.now().millisecondsSinceEpoch}${p.extension(path)}';
      final saved = await File(path).copy(p.join(audioDir.path, name));

      final bytes = await saved.readAsBytes();
      final result = await widget.api.transcribeAudio(
        bytes.toList(),
        p.basename(saved.path),
        language: widget.language,
        model: widget.model,
      );
      result['_audio_path'] = saved.path;
      await widget.onCompleted(result);
      if (mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _processing = false;
          _error = e.toString();
        });
      }
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0
        ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
            if (_recording) {
              _timer?.cancel();
              widget.audioRecorder.stop();
            }
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: _processing
            ? _processingView(theme)
            : _recordingView(theme),
      ),
    );
  }

  Widget _recordingView(ThemeData theme) {
    final isRecording = _recording && !_paused;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Timer
          Text(
            _formatDuration(_elapsed),
            style: theme.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w300,
              color: isRecording ? Colors.red : theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          // Status text
          Text(
            _recording
                ? (_paused ? 'Đã tạm dừng' : 'Đang ghi âm...')
                : 'Sẵn sàng ghi âm',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: _recording ? Colors.red : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          if (_recording)
            // Recording indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isRecording)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                if (isRecording) const SizedBox(width: 8),
                Text(
                  isRecording ? 'REC' : 'PAUSED',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          if (_recording) ...[
            const SizedBox(height: 24),
            _amplitudeMeter(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          ],
          const SizedBox(height: 48),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (_recording)
                IconButton.filledTonal(
                  onPressed: _toggleRecord,
                  icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                  iconSize: 32,
                  tooltip: _paused ? 'Tiếp tục' : 'Tạm dừng',
                ),
              // Main button
              GestureDetector(
                onTap: _recording ? _stopAndProcess : _toggleRecord,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _recording ? Colors.red : theme.colorScheme.primary,
                  ),
                  child: Icon(
                    _recording ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
              // Spacer to balance layout
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 24),
          if (!_recording)
            Text(
              'Nhấn nút micro để bắt đầu ghi âm',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          if (_recording)
            Text(
              _paused
                  ? 'Nhấn play để tiếp tục, hoặc nút đỏ để kết thúc'
                  : 'Nhấn nút đỏ để kết thúc và chuyển thành văn bản',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  /// Chi bao muc am luong (dBFS -> 24 vach), cap nhat 10 lan/giay.
  Widget _amplitudeMeter() {
    const bars = 24;
    final normalized = ((_amp + 60) / 60).clamp(0.0, 1.0);
    final active = (normalized * bars).round().clamp(0, bars);
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(bars, (i) {
          final on = i < active;
          final ratio = i / bars;
          final color = ratio < 0.6
              ? Colors.green
              : ratio < 0.85
                  ? Colors.amber
                  : Colors.red;
          return Container(
            width: 6,
            height: 12.0 + ratio * 32,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: on ? color : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }

  Widget _processingView(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 64,
          height: 64,
          child: CircularProgressIndicator(strokeWidth: 4),
        ),
        const SizedBox(height: 24),
        Text(
          'Đang nhận dạng giọng nói...',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Mô hình: ${widget.model}',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: 8),
        const Text(
          'Vui lòng đợi, quá trình này có thể mất vài giây.',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}
