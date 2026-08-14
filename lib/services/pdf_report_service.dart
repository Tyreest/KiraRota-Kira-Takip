import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';
import 'package:kira_artisi_hesapla/core/constants.dart';
import 'package:kira_artisi_hesapla/core/format.dart';
import 'package:kira_artisi_hesapla/domain/models/calculation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// PDF kaydetme sonucu (SAF / paylaşım).
enum PdfSaveOutcome {
  /// Kullanıcı konum seçti ve dosya yazıldı.
  saved,

  /// Kullanıcı seçiciyi iptal etti — hata gösterilmez.
  cancelled,

  /// Yazma / platform hatası.
  failed,
}

class PdfSaveResult {
  const PdfSaveResult(this.outcome, {this.path, this.error});

  final PdfSaveOutcome outcome;
  final String? path;
  final Object? error;

  bool get isSuccess => outcome == PdfSaveOutcome.saved;
}

class PdfReportService {
  /// Varsayılan dosya adı (uzantısız), örn. `kirarota-2026-05`.
  String reportBaseFileName(CalculationResult result, {String? rentalName}) {
    final suffix = rentalName != null && rentalName.trim().isNotEmpty
        ? '-${rentalName.trim().replaceAll(' ', '-').toLowerCase()}'
        : '';
    return 'kirarota$suffix-${result.input.renewalMonthKey}';
  }

  String reportFileName(CalculationResult result, {String? rentalName}) =>
      '${reportBaseFileName(result, rentalName: rentalName)}.pdf';

  Future<void> shareCalculation(
    CalculationResult result, {
    String? rentalName,
  }) async {
    final bytes = await buildPdfBytes(result, rentalName: rentalName);
    await Printing.sharePdf(
      bytes: bytes,
      filename: reportFileName(result, rentalName: rentalName),
    );
  }

  /// Android SAF (`ACTION_CREATE_DOCUMENT`) — konum/ad kullanıcı seçer; ekstra
  /// depolama izni gerekmez.
  Future<PdfSaveResult> saveCalculationToDevice(
    CalculationResult result, {
    String? rentalName,
  }) async {
    try {
      final bytes = await buildPdfBytes(result, rentalName: rentalName);
      final path = await FileSaver.instance.saveAs(
        name: reportBaseFileName(result, rentalName: rentalName),
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
      if (path == null || path.trim().isEmpty) {
        return const PdfSaveResult(PdfSaveOutcome.cancelled);
      }
      return PdfSaveResult(PdfSaveOutcome.saved, path: path);
    } on MissingPluginException catch (e) {
      return PdfSaveResult(PdfSaveOutcome.failed, error: e);
    } catch (e) {
      // Bazı platformlarda iptal exception olarak gelebilir.
      final msg = e.toString().toLowerCase();
      if (msg.contains('cancel') || msg.contains('iptal')) {
        return const PdfSaveResult(PdfSaveOutcome.cancelled);
      }
      return PdfSaveResult(PdfSaveOutcome.failed, error: e);
    }
  }

  /// Bundled Noto Sans — offline Türkçe / ₺ desteği (Google Fonts indirmeye bağımlı değil).
  Future<Uint8List> buildPdfBytes(
    CalculationResult result, {
    String? rentalName,
  }) async {
    final baseData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final italicData = await rootBundle.load(
      'assets/fonts/NotoSans-Italic.ttf',
    );
    final base = pw.Font.ttf(baseData);
    final bold = pw.Font.ttf(boldData);
    final italic = pw.Font.ttf(italicData);

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: base, bold: bold, italic: italic),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                AppConstants.appName,
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text('Kira artışı özet raporu'),
              if (rentalName != null && rentalName.trim().isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Text(
                  'Kayıt: ${rentalName.trim()}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
              pw.SizedBox(height: 24),
              pw.Text(
                'Hesaplanan yeni kira',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                formatMoney(result.calculatedRent),
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Artış tutarı: ${formatMoney(result.increaseAmount)}'),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 12),
              _row('Mevcut aylık kira', formatMoney(result.input.currentRent)),
              _row('Kira artış tarihi', formatDateTr(result.input.renewalDate)),
              _row(
                'TÜFE esaslı azami artış oranı',
                formatPercent(result.tufeMaxRatePercent),
              ),
              _row(
                'Uygulanan oran',
                formatPercent(result.applicableRatePercent),
              ),
              if (result.input.contractIncreasePercent != null)
                _row(
                  'Sözleşmedeki artış oranı',
                  formatPercent(result.input.contractIncreasePercent!),
                ),
              _row(
                'TÜİK açıklama tarihi',
                formatDateTr(result.tuikReleaseDate),
              ),
              _row('Veri güncelleme', formatDateTr(result.datasetUpdatedAt)),
              if (result.isFiveYearsOrMore) ...[
                pw.SizedBox(height: 16),
                pw.Text(
                  '5+ yıl notu',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(AppConstants.fiveYearWarning),
              ],
              pw.Spacer(),
              pw.Text(
                AppConstants.disclaimerShort,
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                AppConstants.notOfficialDisclaimer,
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Yıllık TÜFE ile 12 aylık ortalama değişim oranı aynı değildir.',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
