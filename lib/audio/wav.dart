import 'dart:typed_data';

/// Dong goi PCM 16-bit thanh WAV (header 44 byte) de gui cho backend.
Uint8List pcmToWav(
  List<int> pcm, {
  int sampleRate = 16000,
  int channels = 1,
  int bitsPerSample = 16,
}) {
  final dataSize = pcm.length;
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;

  final header = BytesBuilder();
  void str(String s) => header.add(s.codeUnits);
  void u32(int v) => header.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  void u16(int v) => header.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));

  str('RIFF');
  u32(36 + dataSize);
  str('WAVE');
  str('fmt ');
  u32(16);
  u16(1); // PCM
  u16(channels);
  u32(sampleRate);
  u32(byteRate);
  u16(blockAlign);
  u16(bitsPerSample);
  str('data');
  u32(dataSize);

  final out = BytesBuilder();
  out.add(header.toBytes());
  out.add(pcm);
  return out.toBytes();
}
