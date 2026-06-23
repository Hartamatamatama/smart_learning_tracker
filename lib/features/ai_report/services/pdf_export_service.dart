import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/ai_evaluation.dart';

/// Generate, simpan, dan bagikan laporan AI sebagai PDF.
///
/// Keputusan: grafik diletakkan sebagai LAMPIRAN VISUAL di bagian akhir
/// (bukan disisipkan di tengah teks). Alasannya: menjaga alur narasi analisis
/// AI tetap mengalir & mudah dibaca, mengelompokkan visual jadi satu blok rapi,
/// sekaligus lebih aman terhadap page-break otomatis (gambar tidak terpotong
/// di tengah paragraf).
class PdfExportService {
  PdfExportService._();

  // Warna selaras palet app, namun versi yang kontras di atas kertas putih.
  static const _accent = PdfColor.fromInt(0xFF6F9A00); // lime gelap (cetak)
  static const _ink = PdfColor.fromInt(0xFF16181A);
  static const _muted = PdfColor.fromInt(0xFF6B6F73);

  // Buang emoji/simbol yang tak ada di font standar PDF agar tak jadi kotak.
  static final _emoji = RegExp(
    r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2190}-\u{21FF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}\u{2728}\u{2B50}]',
    unicode: true,
  );
  static String _clean(String s) => s.replaceAll(_emoji, '').trimRight();

  static Future<Uint8List> generateReportPdf({
    required AiEvaluation evaluation,
    required List<Uint8List> chartImages,
    required String userName,
  }) async {
    final doc = pw.Document();
    final base = pw.TextStyle(fontSize: 10.5, color: _ink, lineSpacing: 2);
    final h2 = pw.TextStyle(
        fontSize: 13, fontWeight: pw.FontWeight.bold, color: _accent);
    final images =
        chartImages.map((b) => pw.MemoryImage(b)).toList(growable: false);
    const captions = [
      'Menit belajar per topik',
      'Tren rata-rata fokus',
      'Proporsi sesi selesai vs dihentikan',
    ];

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 36),
        header: (ctx) =>
            ctx.pageNumber == 1 ? _title() : pw.SizedBox(height: 0),
        footer: (ctx) => _footer(ctx),
        build: (ctx) => [
          // metaBox jadi widget pertama → otomatis tampil di halaman 1.
          _metaBox(evaluation, userName),
          pw.SizedBox(height: 14),
          pw.Text('Analisis AI', style: h2),
          pw.Divider(color: PdfColors.grey300, thickness: 0.8),
          pw.SizedBox(height: 6),
          ..._markdown(_clean(evaluation.reportMarkdown ?? '(Tidak ada teks.)'),
              base, h2),
          // Lampiran visual dipaksa mulai di halaman baru → teks AI penuh di
          // halaman sebelumnya, semua grafik berkumpul rapi di lampiran.
          if (images.isNotEmpty) pw.NewPage(),
          pw.Text('Lampiran: Ringkasan Visual', style: h2),
          pw.Divider(color: PdfColors.grey300, thickness: 0.8),
          pw.SizedBox(height: 8),
          for (var i = 0; i < images.length; i++)
            // Container (bukan Column) → pasangan caption+grafik bersifat atomik,
            // tidak akan terpisah/terpotong saat ganti halaman.
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 16),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(captions[i],
                      style: pw.TextStyle(
                          fontSize: 10,
                          color: _muted,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.ClipRRect(
                      horizontalRadius: 6,
                      verticalRadius: 6,
                      child: pw.Image(images[i], width: 340),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    return doc.save();
  }

  // ---- Bagian-bagian layout ------------------------------------------------

  static pw.Widget _title() => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 4),
        padding: const pw.EdgeInsets.only(bottom: 10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _accent, width: 2)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Laporan Evaluasi Belajar',
                style: pw.TextStyle(
                    fontSize: 20, fontWeight: pw.FontWeight.bold, color: _ink)),
            pw.SizedBox(height: 2),
            pw.Text('Smart Learning Tracker',
                style: pw.TextStyle(fontSize: 11, color: _muted)),
          ],
        ),
      );

  static pw.Widget _metaBox(AiEvaluation e, String userName) {
    pw.Widget row(String k, String v) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(children: [
            pw.SizedBox(
                width: 110,
                child: pw.Text(k,
                    style: pw.TextStyle(fontSize: 10, color: _muted))),
            pw.Text(v,
                style: pw.TextStyle(
                    fontSize: 10,
                    color: _ink,
                    fontWeight: pw.FontWeight.bold)),
          ]),
        );
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          row('Nama', userName),
          row('Periode', '${e.periodDays} Hari Terakhir'),
          row('Dibuat', _fmtDateTime(e.generatedAt)),
          row('Total sesi', '${e.sessionCount} sesi'),
          row('Total menit', '${e.totalMinutes} menit'),
        ],
      ),
    );
  }

  static pw.Widget _footer(pw.Context ctx) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 8),
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Smart Learning Tracker',
                style: pw.TextStyle(fontSize: 8, color: _muted)),
            pw.Text('Halaman ${ctx.pageNumber} dari ${ctx.pagesCount}',
                style: pw.TextStyle(fontSize: 8, color: _muted)),
          ],
        ),
      );

  // ---- Markdown ringan → widget PDF ---------------------------------------

  static List<pw.Widget> _markdown(
      String md, pw.TextStyle body, pw.TextStyle h2) {
    final widgets = <pw.Widget>[];
    for (final raw in md.replaceAll('\r\n', '\n').split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        widgets.add(pw.SizedBox(height: 6));
        continue;
      }
      if (line.startsWith('## ') || line.startsWith('# ')) {
        final text = line.replaceFirst(RegExp(r'^#+\s*'), '');
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
          child: pw.Text(text, style: h2),
        ));
      } else if (line.startsWith('### ')) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6, bottom: 3),
          child: pw.Text(line.substring(4),
              style: body.copyWith(fontWeight: pw.FontWeight.bold)),
        ));
      } else if (line.trimLeft().startsWith('- ') ||
          line.trimLeft().startsWith('* ')) {
        final content = line.trimLeft().substring(2);
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(left: 6, bottom: 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 4,
                height: 4,
                margin: const pw.EdgeInsets.only(top: 4.5, right: 6),
                decoration:
                    const pw.BoxDecoration(color: _accent, shape: pw.BoxShape.circle),
              ),
              pw.Expanded(child: _inline(content, body)),
            ],
          ),
        ));
      } else {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: _inline(line, body),
        ));
      }
    }
    return widgets;
  }

  /// Parse **bold** inline (segmen ganjil = tebal).
  static pw.Widget _inline(String text, pw.TextStyle base) {
    final parts = text.split('**');
    final spans = <pw.TextSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(pw.TextSpan(
        text: parts[i],
        style: i.isOdd ? base.copyWith(fontWeight: pw.FontWeight.bold) : base,
      ));
    }
    return pw.RichText(text: pw.TextSpan(style: base, children: spans));
  }

  // ---- Nama file, share, save ---------------------------------------------

  static String fileName(AiEvaluation e) {
    final d = e.generatedAt;
    final ds =
        '${d.year}${_pad2(d.month)}${_pad2(d.day)}_${_pad2(d.hour)}${_pad2(d.minute)}';
    return 'Laporan_SmartLearningTracker_${e.periodDays}hari_$ds.pdf';
  }

  static Future<void> sharePdf(Uint8List bytes, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: 'Laporan evaluasi belajar — Smart Learning Tracker',
    );
  }

  /// Simpan ke folder Downloads publik bila bisa (Android ≤ 9 / sebagian
  /// device); kalau tidak, fallback ke folder penyimpanan app. Kembalikan path.
  static Future<String> savePdf(Uint8List bytes, String filename) async {
    try {
      final downloads = Directory('/storage/emulated/0/Download');
      if (await downloads.exists()) {
        final f = File('${downloads.path}/$filename');
        await f.writeAsBytes(bytes, flush: true);
        return f.path;
      }
    } catch (_) {
      // scoped storage menolak → pakai fallback
    }
    final dir =
        await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/$filename');
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }

  static String _pad2(int n) => n.toString().padLeft(2, '0');
  static String _fmtDateTime(DateTime d) =>
      '${_pad2(d.day)}/${_pad2(d.month)}/${d.year} ${_pad2(d.hour)}:${_pad2(d.minute)}';
}
