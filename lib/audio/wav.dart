import 'dart:typed_data';

/// Dong goi PCM 16-bit thanh WAV (header 44 byte).
Uint8List pcmToWav(
  List<int> pcm, {
  int sampleRate = 16000,
  int channels = 1,
  int bitsPerSample = 16,
}) {
  final dataSize = pcm.length;
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;

  final h = ByteData(44);
  void str(int off, String s) {
    for (var i = 0; i < s.length; i++) {
      h.setUint8(off + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  h.setUint32(4, 36 + dataSize, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  h.setUint32(16, 16, Endian.little);
  h.setUint16(20, 1, Endian.little);
  h.setUint16(22, channels, Endian.little);
  h.setUint32(24, sampleRate, Endian.little);
  h.setUint32(28, byteRate, Endian.little);
  h.setUint16(32, blockAlign, Endian.little);
  h.setUint16(34, bitsPerSample, Endian.little);
  str(36, 'data');
  h.setUint32(40, dataSize, Endian.little);

  final out = BytesBuilder();
  out.add(h.buffer.asUint8List());
  out.add(pcm);
  return out.toBytes();
}
