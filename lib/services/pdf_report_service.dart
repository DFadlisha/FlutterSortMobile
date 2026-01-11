
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:myapp/models/sorting_log.dart';

class PdfReportService {
  Future<void> generateReport(List<SortingLog> logs) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final formattedDate = DateFormat('MMM d, yyyy, h:mm a').format(now);

    final font = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();

    // 1. Executive Summary Data
    int totalSorted = logs.fold(0, (sum, log) => sum + log.quantitySorted);
    int totalNg = logs.fold(0, (sum, log) => sum + log.quantityNg);
    double ngRate = (totalSorted + totalNg) == 0 ? 0 : (totalNg / (totalSorted + totalNg)) * 100;
    int partsProcessed = logs.map((e) => e.partNo).toSet().length;
    String overallStatus = ngRate > 5.0 ? 'ACTION REQUIRED' : 'STABLE';

    // 2. Production Summary Data (Group by Part & Supplier)
    Map<String, Map<String, dynamic>> productionSummary = {};
    for (var log in logs) {
      final key = '${log.partName}|${log.supplier}';
      if (!productionSummary.containsKey(key)) {
        productionSummary[key] = {
          'partName': log.partName,
          'supplier': log.supplier,
          'total': 0,
          'ok': 0,
          'ng': 0,
        };
      }
      productionSummary[key]!['total'] += (log.quantitySorted + log.quantityNg);
      productionSummary[key]!['ok'] += log.quantitySorted;
      productionSummary[key]!['ng'] += log.quantityNg;
    }

    List<List<String>> productionTableData = productionSummary.values.map((e) {
      int total = e['total'];
      int ng = e['ng'];
      double rate = total == 0 ? 0 : (ng / total) * 100;
      return [
        e['partName'].toString(),
        e['supplier'].toString(),
        total.toString(),
        e['ok'].toString(),
        ng.toString(),
        '${rate.toStringAsFixed(2)}%'
      ];
    }).toList();

    // 3. Defect Analysis Data (Group by NG Type)
    Map<String, int> defectCounts = {};
    for (var log in logs) {
      if (log.quantityNg > 0 && log.ngType.isNotEmpty) {
        defectCounts[log.ngType] = (defectCounts[log.ngType] ?? 0) + log.quantityNg;
      }
    }
    
    List<List<String>> defectTableData = defectCounts.entries.map((entry) {
      double pct = totalNg == 0 ? 0 : (entry.value / totalNg) * 100;
      return [
        entry.key,
        entry.value.toString(),
        '${pct.toStringAsFixed(1)}%',
        '' // Visual placeholder
      ];
    }).toList();


    // 4. Detailed Logs Data (Last 25)
    final sortedLogs = List<SortingLog>.from(logs)..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final recentLogs = sortedLogs.take(25).toList();
    
    List<List<String>> logsTableData = recentLogs.map((log) {
      final date = log.timestamp.toDate();
      final dateStr = DateFormat('M/d, HH:mm').format(date);
      final total = log.quantitySorted + log.quantityNg;
      double rate = total == 0 ? 0 : (log.quantityNg / total) * 100;
      return [
        dateStr,
        log.partName,
        log.supplier,
        total.toString(),
        log.quantityNg.toString(),
        log.ngType,
        '${rate.toStringAsFixed(1)}%'
      ];
    }).toList();


    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: pw.ThemeData.withFont(base: font, bold: boldFont),
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
        ),
        header: (context) => pw.Column(
          children: [
            pw.Text(
              'QUALITY SORTING INSPECTION REPORT',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 5),
            pw.Text('Generated: $formattedDate', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.SizedBox(height: 20),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 20),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}  |  CONFIDENTIAL - INTERNAL USE ONLY',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          ),
        ),
        build: (context) => [
          // 1. Executive Summary
          pw.Header(level: 1, text: '1. EXECUTIVE SUMMARY', textStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.Table.fromTextArray(
            headers: ['Total Sorted', 'Total NG', 'NG Rate', 'Parts Processed', 'Overall Status'],
            data: [
              [
                NumberFormat('#,###').format(totalSorted),
                NumberFormat('#,###').format(totalNg),
                '${ngRate.toStringAsFixed(2)}%',
                partsProcessed.toString(),
                overallStatus
              ]
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignment: pw.Alignment.center,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellHeight: 30,
          ),
          pw.SizedBox(height: 20),

          // 2. Production Summary
          pw.Header(level: 1, text: '2. PRODUCTION SUMMARY (BY PART & SUPPLIER)', textStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.Table.fromTextArray(
            headers: ['Part Name', 'Supplier', 'Total', 'OK', 'NG', 'Rate'],
            data: productionTableData,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 20),

          // 3. Defect Analysis
          pw.Header(level: 1, text: '3. DEFECT ANALYSIS', textStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.Table.fromTextArray(
            headers: ['Defect Type', 'Qty', '%', 'Visual'],
            data: defectTableData,
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(2),
            },
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
             cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerLeft,
            },
          ),
          pw.SizedBox(height: 20),

          // 4. Detailed Logs
          pw.Header(level: 1, text: '4. DETAILED LOGS (LAST 25)', textStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.Table.fromTextArray(
            headers: ['Time', 'Part', 'Supplier', 'Total', 'NG', 'Type', 'Rate'],
            data: logsTableData,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerLeft,
              6: pw.Alignment.centerRight,
            },
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Quality_Report_${DateFormat('yyyyMMdd').format(now)}',
    );
  }
}
