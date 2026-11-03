import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../api_service.dart';
import '../audio/wav.dart';
import '../data/recording.dart';

const int _kSampleRate = 16000;
const int _kChunkSeconds = 3;

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
  bool _live = true;

  Duration _elapsed = Duration.zero;
  Timer? _timer;
  String? _error;

  StreamSubscription<Amplitude>? _ampSub;
  StreamSubscription<Uint8List>? _pcmSub;
  double _amp = -60;

  final List<int> _pcmAll = [];
  final List<int> _buffer = [];
  bool _sending = false;
  String _confirmed = '';
  String _pending = '';
  bool _streamMode = false;

  int get _chunkBytes => _kSampleRate * 2 * _kChunkSeconds;

  @override
  void dispose() {
    _timer?.cancel();
    _ampSub?.cancel();
    _pcmSub?.cancel();
    super.dispose();
  }

  // ---------------- Recording control -------------

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
      await _start();
    }
  }

  Future<void> _start() async {
    if (!await widget.audioRecorder.hasPermission()) {
      setState(() => _error = 'Chưa được cấp quyền ghi âm (microphone).');
      return;
    }
    try {
      final stream = await widget.audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bit,
          sampleRate: _kSampleRate,
          numChannels: 1,
        ),
      );
      _streamMode = true;
      _pcmAll.clear();
      _buffer.clear();
      _confirmed = '';
      _pending = '';
      _pcmSub = stream.listen(
        _onPcm,
        onError: (_) {},
        cancelOnError: false,
      );
      _listenAmplitude();
    } catch (_) {
      // Thiet bi khong ho tro stream -> ghi ra file nhu cu.
      _streamMode = false;
      final dir = await getTemporaryDirectory();
      await widget.audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: _kSampleRate,
          numChannels: 1,
        ),
        path: '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav',
      );
      _listenAmplitude();
    }
    setState(() => _recording = true);
    _startTimer();
  }

  void _startTimer() {
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

  // ---------------- Live transcription -------------

  void _onPcm(Uint8List chunk) {
    _pcmAll.addAll(chunk);
    if (!_live) return;
    _buffer.addAll(chunk);
    if (_buffer.length >= _chunkBytes) {
      _flushBuffer();
    }
  }

  /// Gui doan da du 3 giay len backend de hien chu ngay.
  Future<void> _flushBuffer() async {
    if (_sending || _buffer.isEmpty) return;
    _sending = true;
    final pcm = List<int>.from(_buffer);
    _buffer.clear();
    final wav = pcmToWav(pcm, sampleRate: _kSampleRate);
    setState(() => _pending = '…');
    final text = await widget.api.transcribeChunk(
      wav,
      language: widget.language,
      model: 'small',
    );
    _sending = false;
    if (!mounted) return;
    setState(() {
      if (text != null && text.trim().isNotEmpty) {
        _confirmed = _confirmed.isEmpty
            ? text.trim()
            : '$_confirmed ${text.trim()}';
      }
      _pending = '';
    });
    // Neu trong luc cho ma buffer da day lai thi gui tiep.
    if (_buffer.length >= _chunkBytes) _flushBuffer();
  }

  // ---------------- Finish -------------

  Future<void> _stopAndProcess() async {
    _timer?.cancel();
    _ampSub?.cancel();
    setState(() {
      _recording = false;
      _paused = false;
      _processing = true;
    });

    try {
      String? audioPath;

      if (_streamMode) {
        await _pcmSub?.cancel();
        _pcmSub = null;
        await widget.audioRecorder.stop();
        // Gui not doan cuoi de khong mat chu.
        if (_live && _buffer.isNotEmpty && !_sending) {
          await _flushBuffer();
        }
        audioPath = await _saveWav();
      } else {
        final path = await widget.audioRecorder.stop();
        if (path == null) {
          throw Exception('Không lưu được file ghi âm');
        }
        audioPath = await _persist(path);
      }

      final bytes = await File(audioPath).readAsBytes();
      final result = await widget.api.transcribeAudio(
        bytes.toList(),
        p.basename(audioPath),
        language: widget.language,
        model: widget.model,
      );
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

  Future<Directory> _audioDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'recordings'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<String> _saveWav() async {
    final dir = await _audioDir();
    final file = File(
      p.join(dir.path, 'rec_${DateTime.now().millisecondsSinceEpoch}.wav'),
    );
    await file.writeAsBytes(
      pcmToWav(_pcmAll, sampleRate: _kSampleRate),
      flush: true,
    );
    return file.path;
  }

  Future<String> _persist(String tempPath) async {
    final dir = await _audioDir();
    final name =
        'rec_${DateTime.now().millisecondsSinceEpoch}${p.extension(tempPath)}';
    final saved = await File(tempPath).copy(p.join(dir.path, name));
    return saved.path;
  }

  // ---------------- UI -------------

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
            _pcmSub?.cancel();
            widget.audioRecorder.stop();
            Navigator.pop(context);
          },
        ),
        actions: [
          if (_recording)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  const Text('Hiện chữ', style: TextStyle(fontSize: 13)),
                  Switch(
                    value: _live,
                    onChanged: (v) => setState(() => _live = v),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _processing
          ? _processingView(theme)
          : Column(
              children: [
                Expanded(child: _recordHeader(theme)),
                if (_live) Expanded(flex: 2, child: _liveText(theme)),
                _controls(theme),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _recordHeader(ThemeData theme) {
    final isRecording = _recording && !_paused;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
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
        if (_recording) ...[
          const SizedBox(height: 14),
          _amplitudeMeter(),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          ),
      ],
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

  Widget _liveText(ThemeData theme) {
    final hasText = _confirmed.isNotEmpty || _pending.isNotEmpty;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        reverse: true,
        child: hasText
            ? RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(text: _confirmed),
                    if (_pending.isNotEmpty)
                      TextSpan(
                        text: ' $_pending',
                        style: TextStyle(
                          color: theme.colorScheme.outline,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              )
            : Center(
                child: Text(
                  _recording
                      ? 'Đang nghe... chữ sẽ hiện ở đây'
                      : 'Bật “Hiện chữ” để xem văn bản ngay khi nói',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _controls(ThemeData theme) {
    return Row(
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
              color: _recording ? Colors.red : theme.colorScheme.primary,
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
            Text('Đang nhận dạng giọng nói...', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Mô hình: ${widget.model}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text('Vui lòng đợi, quá trình này có thể mất vài giây.',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
}
