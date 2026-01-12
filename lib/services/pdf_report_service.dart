
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

    // 2. Production Summary Data (Group by Part, Supplier & Location)
    Map<String, Map<String, dynamic>> productionSummary = {};
    for (var log in logs) {
      final key = '${log.partName}|${log.supplier}|${log.factoryLocation}';
      if (!productionSummary.containsKey(key)) {
        productionSummary[key] = {
          'partName': log.partName,
          'supplier': log.supplier,
          'location': log.factoryLocation,
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
        e['location'].toString(),
        total.toString(),
        e['ok'].toString(),
        ng.toString(),
        '${rate.toStringAsFixed(2)}%'
      ];
    }).toList();

    // 3. Defect Analysis Data (Group by NG Type from all details)
    Map<String, int> defectCounts = {};
    for (var log in logs) {
      for (var detail in log.ngDetails) {
        if (detail.type.isNotEmpty) {
          defectCounts[detail.type] = (defectCounts[detail.type] ?? 0) + 1;
        }
      }
    }
    
    List<List<String>> defectTableData = defectCounts.entries.map((entry) {
      int totalOccurrences = defectCounts.values.fold(0, (a, b) => a + b);
      double pct = totalOccurrences == 0 ? 0 : (entry.value / totalOccurrences) * 100;
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
      
      String ngTypes = log.ngDetails.map((e) => e.type).toSet().join(", ");
      if (ngTypes.isEmpty) ngTypes = "-";
      
      String ops = log.operators.join(", ");
      if (ops.isEmpty) ops = "-";
      
      return [
        dateStr,
        ops,
        log.partName,
        log.supplier,
        log.factoryLocation,
        total.toString(),
        log.quantityNg.toString(),
        ngTypes,
        '${rate.toStringAsFixed(1)}%'
      ];
    }).toList();


    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: pw.ThemeData.withFont(base: font, bold: boldFont),
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
        ),
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('QUALITY CONTROL SYSTEM REPORT',
                        style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#1A237E'))),
                    pw.SizedBox(height: 4),
                    pw.Text('NES SOLUTION AND NETWORK SDN BHD',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('INSPECTION SUMMARY',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo)),
                    pw.Text(formattedDate, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 1, color: PdfColors.indigo),
            pw.SizedBox(height: 15),
          ],
        ),
        footer: (context) => pw.Column(
          children: [
            pw.Divider(thickness: 0.5, color: PdfColors.grey400),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('QCSR Mobile - Digital Traceability System',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
              ],
            ),
          ],
        ),
        build: (context) => [
          // 1. Executive Summary Cards
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryCard('Total Sorted', NumberFormat('#,###').format(totalSorted), PdfColors.indigo),
              _buildSummaryCard('Total NG', NumberFormat('#,###').format(totalNg), PdfColors.orange800),
              _buildSummaryCard('NG Rate', '${ngRate.toStringAsFixed(2)}%', PdfColors.red800),
              _buildSummaryCard('Status', overallStatus, overallStatus == 'STABLE' ? PdfColors.green800 : PdfColors.red800),
            ],
          ),
          pw.SizedBox(height: 25),

          // 2. Production Summary
          _buildSectionTitle('1. PRODUCTION SUMMARY (BY PART, SUPPLIER & LOC)'),
          pw.Table.fromTextArray(
            headers: ['Part Name', 'Supplier', 'Location', 'Total', 'OK', 'NG', 'Rate'],
            data: productionTableData,
            headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignments: {0: pw.Alignment.centerLeft, 3: pw.Alignment.centerRight, 4: pw.Alignment.centerRight, 5: pw.Alignment.centerRight, 6: pw.Alignment.centerRight},
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            cellAlignments: {
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 25),

          // 3. Operator Performance
          _buildSectionTitle('2. OPERATOR PERFORMANCE RANKING'),
          pw.Table.fromTextArray(
            headers: ['Rank', 'Operator Name', 'Total OK', 'NG Found', 'Quality Score'],
            data: _calculateLeaderboard(logs),
            headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            cellAlignments: {
              0: pw.Alignment.center,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 25),

          // 4. Defect Analysis
          _buildSectionTitle('3. DEFECT ANALYSIS (BY TYPE OCCURRENCE)'),
          pw.Table.fromTextArray(
            headers: ['Defect Type', 'Occurrences', '% Frequency', 'Visual Summary'],
            data: defectTableData,
            headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
            cellStyle: const pw.TextStyle(fontSize: 8),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(2),
            },
            cellAlignments: {
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 25),

          // 5. Detailed Logs
          _buildSectionTitle('4. DETAILED INSPECTION LOGS (RECENT)'),
          pw.Table.fromTextArray(
            headers: ['Time', 'Operators', 'Part', 'Supplier', 'Location', 'Total', 'NG', 'NG Types', 'Rate'],
            data: logsTableData,
            headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellPadding: const pw.EdgeInsets.all(3),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            cellAlignments: {
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              8: pw.Alignment.centerRight,
            },
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'QCSR_Report_${DateFormat('yyyyMMdd').format(now)}',
    );
  }

  pw.Widget _buildSummaryCard(String title, String value, PdfColor color) {
    return pw.Container(
      width: 110,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: color.shade(0.2), width: 1),
      ),
      child: pw.Column(
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
        pw.SizedBox(height: 5),
        pw.Container(height: 1, color: PdfColors.indigo100),
        pw.SizedBox(height: 10),
      ],
    );
  }

  List<List<String>> _calculateLeaderboard(List<SortingLog> logs) {
    Map<String, Map<String, int>> stats = {};
    for (var log in logs) {
      final ops = log.operators.isEmpty ? ["Unknown"] : log.operators;
      final splitOk = (log.quantitySorted / ops.length).floor();
      final splitNg = (log.quantityNg / ops.length).floor();
      
      for (var op in ops) {
        stats.putIfAbsent(op, () => {'ok': 0, 'ng': 0});
        stats[op]!['ok'] = stats[op]!['ok']! + splitOk;
        stats[op]!['ng'] = stats[op]!['ng']! + splitNg;
      }
    }

    var sortedOps = stats.entries.toList()
      ..sort((a, b) => b.value['ok']!.compareTo(a.value['ok']!));

    List<List<String>> rows = [];
    for (int i = 0; i < sortedOps.length; i++) {
      final entry = sortedOps[i];
      final ok = entry.value['ok']!;
      final ng = entry.value['ng']!;
      final total = ok + ng;
      final quality = total == 0 ? 0 : (ok / total) * 100;

      rows.add([
        (i + 1).toString(),
        entry.key,
        ok.toString(),
        ng.toString(),
        '${quality.toStringAsFixed(1)}%'
      ]);
    }
    return rows;
  }
}
