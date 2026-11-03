import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../data/recording.dart';

enum ExportFormat { txt, pdf, docx }

/// Tao va chia se file xuat tu mot ban ghi.
class Exporter {
  static String _stamp(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}'
      '_${d.hour.toString().padLeft(2, '0')}${d.minute.toString().padLeft(2, '0')}';

  static String safeName(Recording r) {
    final base = r.title.replaceAll(RegExp(r'[^\p{L}\p{N} _-]', unicode: true), '').trim();
    final name = base.isEmpty ? 'ban_ghi' : base;
    return '${name.length > 50 ? name.substring(0, 50) : name}_${_stamp(r.createdAt)}';
  }

  /// Noi dung van ban thuan (dung cho TXT va chia se nhanh).
  static String toText(Recording r) {
    final b = StringBuffer();
    b.writeln(r.title);
    b.writeln('=' * r.title.length.clamp(3, 60));
    b.writeln('Thoi gian: ${_humanDate(r.createdAt)}');
    if (r.duration != null) b.writeln('Thoi luong: ${_humanDuration(r.duration!)}');
    if (r.model != null) b.writeln('Mo hinh: ${r.model}');
    b.writeln();
    b.writeln('--- BAN CHEP LOI ---');
    if (r.segments.isNotEmpty) {
      for (final s in r.segments) {
        final seg = s as Map;
        final start = (seg['start'] as num?)?.toDouble() ?? 0;
        b.writeln('[${_ts(start)}] ${(seg['text'] ?? '').toString().trim()}');
      }
    } else {
      b.writeln(r.transcript);
    }
    b.writeln();
    b.writeln('--- TOM TAT ---');
    b.writeln((r.summary['summary'] ?? '').toString());
    final topics = (r.summary['topics'] as List?) ?? const [];
    if (topics.isNotEmpty) {
      b.writeln();
      b.writeln('Chu de: ${topics.join(', ')}');
    }
    final decisions = (r.summary['decisions'] as List?) ?? const [];
    if (decisions.isNotEmpty) {
      b.writeln();
      b.writeln('Quyet dinh:');
      for (final d in decisions) {
        b.writeln('  - $d');
      }
    }
    final actions = (r.summary['action_items'] as List?) ?? const [];
    if (actions.isNotEmpty) {
      b.writeln();
      b.writeln('Viec can lam:');
      for (final a in actions) {
        final m = a as Map;
        final owner = m['owner'];
        final due = m['due'];
        final extra = [
          if (owner != null) 'phu trach: $owner',
          if (due != null) 'han: $due',
        ].join(', ');
        b.writeln('  - ${m['task']}${extra.isEmpty ? '' : ' ($extra)'}');
      }
    }
    final questions = (r.summary['open_questions'] as List?) ?? const [];
    if (questions.isNotEmpty) {
      b.writeln();
      b.writeln('Cau hoi / vuong mac:');
      for (final q in questions) {
        b.writeln('  - $q');
      }
    }
    b.writeln();
    b.writeln('_Tao boi VietVoice_');
    return b.toString();
  }

  static Future<pw.Font> _font(String asset) async {
    final data = await rootBundle.load(asset);
    return pw.Font.ttf(data);
  }

  static Future<Uint8List> toPdf(Recording r) async {
    final regular = await _font('assets/fonts/Roboto-Regular.ttf');
    final bold = await _font('assets/fonts/Roboto-Bold.ttf');
    final doc = pw.Document();
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        theme: theme,
        header: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text('VietVoice',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text('Trang ${ctx.pageNumber}/${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ),
        build: (ctx) => [
          pw.Text(r.title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            [
              _humanDate(r.createdAt),
              if (r.duration != null) _humanDuration(r.duration!),
              if (r.model != null) r.model!,
            ].join('  ·  '),
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.Divider(height: 20),
          pw.Text('BẢN CHÉP LỜI',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (r.segments.isNotEmpty)
            ...r.segments.map((s) {
              final seg = s as Map;
              final start = (seg['start'] as num?)?.toDouble() ?? 0;
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 42,
                      child: pw.Text(_ts(start),
                          style: pw.TextStyle(fontSize: 8, color: PdfColors.indigo400)),
                    ),
                    pw.Expanded(
                      child: pw.Text((seg['text'] ?? '').toString().trim(),
                          style: const pw.TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              );
            })
          else
            pw.Text(r.transcript, style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 18),
          pw.Text('TÓM TẮT',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if ((r.summary['summary'] ?? '').toString().isNotEmpty)
            pw.Text(r.summary['summary'].toString(),
                style: const pw.TextStyle(fontSize: 11)),
          ..._pdfList('Chủ đề chính', r.summary['topics']),
          ..._pdfList('Quyết định', r.summary['decisions']),
          ..._pdfActions(r.summary['action_items']),
          ..._pdfList('Câu hỏi / vướng mắc', r.summary['open_questions']),
        ],
      ),
    );
    return doc.save();
  }

  static List<pw.Widget> _pdfList(String title, dynamic items) {
    final list = (items as List?) ?? const [];
    if (list.isEmpty) return const [];
    return [
      pw.SizedBox(height: 12),
      pw.Text(title,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      ...list.map((e) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3, left: 8),
            child: pw.Text('• $e', style: const pw.TextStyle(fontSize: 11)),
          )),
    ];
  }

  static List<pw.Widget> _pdfActions(dynamic items) {
    final list = (items as List?) ?? const [];
    if (list.isEmpty) return const [];
    return [
      pw.SizedBox(height: 12),
      pw.Text('Việc cần làm',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      ...list.map((a) {
        final m = a as Map;
        final owner = m['owner'];
        final due = m['due'];
        final extra = [
          if (owner != null) 'phụ trách: $owner',
          if (due != null) 'hạn: $due',
        ].join(', ');
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3, left: 8),
          child: pw.Text(
            '☐ ${m['task']}${extra.isEmpty ? '' : ' ($extra)'}',
            style: const pw.TextStyle(fontSize: 11),
          ),
        );
      }),
    ];
  }

  /// DOCX toi gian (OOXML) - mo duoc bang Word / WPS / Google Docs.
  static Uint8List toDocx(Recording r) {
    String esc(String s) => s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');

    String para(String text, {bool bold = false, int size = 22, int spaceAfter = 120}) {
      final rpr = bold ? '<w:rPr><w:b/><w:sz w:val="$size"/></w:rPr>' : '<w:rPr><w:sz w:val="$size"/></w:rPr>';
      return '<w:p><w:pPr><w:spacing w:after="$spaceAfter"/></w:pPr>'
          '<w:r>$rpr<w:t xml:space="preserve">${esc(text)}</w:t></w:r></w:p>';
    }

    final body = StringBuffer();
    body.write(para(r.title, bold: true, size: 36, spaceAfter: 80));
    body.write(para(
      [
        _humanDate(r.createdAt),
        if (r.duration != null) _humanDuration(r.duration!),
        if (r.model != null) r.model!,
      ].join('  ·  '),
      size: 18,
    ));
    body.write(para('BẢN CHÉP LỜI', bold: true, size: 26));
    if (r.segments.isNotEmpty) {
      for (final s in r.segments) {
        final seg = s as Map;
        final start = (seg['start'] as num?)?.toDouble() ?? 0;
        body.write(para('[${_ts(start)}] ${(seg['text'] ?? '').toString().trim()}'));
      }
    } else {
      body.write(para(r.transcript));
    }
    body.write(para(''));
    body.write(para('TÓM TẮT', bold: true, size: 26));
    if ((r.summary['summary'] ?? '').toString().isNotEmpty) {
      body.write(para(r.summary['summary'].toString()));
    }
    for (final entry in [
      ('Chủ đề chính', r.summary['topics']),
      ('Quyết định', r.summary['decisions']),
      ('Câu hỏi / vướng mắc', r.summary['open_questions']),
    ]) {
      final list = (entry.$2 as List?) ?? const [];
      if (list.isEmpty) continue;
      body.write(para(entry.$1, bold: true, size: 22));
      for (final e in list) {
        body.write(para('• $e'));
      }
    }
    final actions = (r.summary['action_items'] as List?) ?? const [];
    if (actions.isNotEmpty) {
      body.write(para('Việc cần làm', bold: true, size: 22));
      for (final a in actions) {
        final m = a as Map;
        body.write(para('☐ ${m['task']}'));
      }
    }

    final document = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:body>$body<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134"/></w:sectPr></w:body>
</w:document>''';

    const contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';

    const rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

    final archive = Archive();
    void add(String name, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    add('[Content_Types].xml', contentTypes);
    add('_rels/.rels', rels);
    add('word/document.xml', document);
    final zipped = ZipEncoder().encode(archive)!;
    return Uint8List.fromList(zipped);
  }

  /// Tao file trong thu muc tam va mo hop thoai chia se cua he dieu hanh.
  static Future<void> share(Recording r, ExportFormat fmt) async {
    final dir = await getTemporaryDirectory();
    final outDir = Directory(p.join(dir.path, 'exports'));
    if (!outDir.existsSync()) outDir.createSync(recursive: true);
    final base = safeName(r);

    late final File file;
    switch (fmt) {
      case ExportFormat.txt:
        file = File(p.join(outDir.path, '$base.txt'));
        await file.writeAsString(toText(r));
      case ExportFormat.pdf:
        file = File(p.join(outDir.path, '$base.pdf'));
        await file.writeAsBytes(await toPdf(r));
      case ExportFormat.docx:
        file = File(p.join(outDir.path, '$base.docx'));
        await file.writeAsBytes(toDocx(r));
    }

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: r.title,
      text: r.title,
    );
  }

  static String _humanDate(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} '
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _humanDuration(double seconds) {
    final s = seconds.round();
    if (s < 60) return '$s giây';
    final m = s ~/ 60;
    final rem = s % 60;
    return rem == 0 ? '$m phút' : '$m phút $rem giây';
  }

  static String _ts(double seconds) {
    final s = seconds.round();
    final m = s ~/ 60;
    return '$m:${(s % 60).toString().padLeft(2, '0')}';
  }
}
