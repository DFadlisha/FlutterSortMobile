import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:myapp/models/sorting_log.dart';
import 'package:intl/intl.dart';

class ExcelExportService {
  Future<String> generateExcelReport(List<SortingLog> logs) async {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Inspection Report'];

    // Set column widths for better readability
    sheet.setColumnWidth(0, 18.0);  // Timestamp
    sheet.setColumnWidth(1, 15.0);  // Part No
    sheet.setColumnWidth(2, 25.0);  // Part Name
    sheet.setColumnWidth(3, 20.0);  // Supplier
    sheet.setColumnWidth(4, 20.0);  // Location
    sheet.setColumnWidth(5, 30.0);  // Team
    sheet.setColumnWidth(6, 12.0);  // Total Sorted
    sheet.setColumnWidth(7, 12.0);  // Total NG
    sheet.setColumnWidth(8, 30.0);  // NG Types

    // Header row with styling
    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#3F51B5'),
      fontColorHex: ExcelColor.white,
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final headers = [
      'Timestamp',
      'Part Number',
      'Part Name',
      'Supplier',
      'Location',
      'Sorting Team',
      'Total Sorted',
      'Total NG',
      'NG Types'
    ];

    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Data rows with alternating colors
    final oddRowStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#F5F5F5'),
    );

    for (int i = 0; i < logs.length; i++) {
      final log = logs[i];
      final rowIndex = i + 1;
      final isOddRow = i % 2 == 0;

      final rowData = [
        DateFormat('yyyy-MM-dd HH:mm').format(log.timestamp.toDate()),
        log.partNo,
        log.partName,
        log.supplier,
        log.factoryLocation,
        log.operators.join(', '),
        log.quantitySorted.toString(),
        log.quantityNg.toString(),
        log.ngDetails.map((e) => e.type).join(', '),
      ];

      for (int j = 0; j < rowData.length; j++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: rowIndex));
        cell.value = TextCellValue(rowData[j]);
        if (isOddRow) {
          cell.cellStyle = oddRowStyle;
        }
      }
    }

    // Save file
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'QCSR_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    final filePath = '${directory.path}/$fileName';
    
    final fileBytes = excel.encode();
    if (fileBytes != null) {
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);
    }

    return filePath;
  }
}
