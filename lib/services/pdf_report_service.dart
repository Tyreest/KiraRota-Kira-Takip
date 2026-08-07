import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:kira_artisi_hesapla/core/constants.dart';
import 'package:kira_artisi_hesapla/core/format.dart';
import 'package:kira_artisi_hesapla/domain/models/calculation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfReportService {
  Future<void> shareCalculation(CalculationResult result) async {
    final bytes = await buildPdfBytes(result);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'kira-artisi-${result.input.renewalMonthKey}.pdf',
    );
  }

  /// Bundled Noto Sans — offline Türkçe / ₺ desteği (Google Fonts indirmeye bağımlı değil).
  Future<Uint8List> buildPdfBytes(CalculationResult result) async {
    final baseData =
        await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final italicData =
        await rootBundle.load('assets/fonts/NotoSans-Italic.ttf');
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
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text(AppConstants.brandName),
              pw.SizedBox(height: 24),
              pw.Text(
                'Bu orana göre hesaplanan kira',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
              pw.Text(
                formatMoney(result.calculatedRent),
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Artış: ${formatMoney(result.increaseAmount)}'),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 12),
              _row('Mevcut aylık kira', formatMoney(result.input.currentRent)),
              _row('Yenileme', formatMonthKey(result.input.renewalMonthKey)),
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
              _row(
                'Veri güncelleme',
                formatDateTr(result.datasetUpdatedAt),
              ),
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
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
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
