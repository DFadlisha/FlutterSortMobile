import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/models/sorting_log.dart';
import 'package:myapp/services/firestore_service.dart';
import 'package:myapp/services/pdf_report_service.dart';
import 'package:myapp/services/excel_export_service.dart';

class ManagementDashboard extends StatelessWidget {
  const ManagementDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();
    final PdfReportService pdfReportService = PdfReportService();
    final ExcelExportService excelExportService = ExcelExportService();

    return DefaultTabController(
      length: 3,
      child: StreamBuilder<List<SortingLog>>(
        stream: firestoreService.getSortingLogs(),
        builder: (context, snapshot) {
          final logs = snapshot.data ?? [];

          return Scaffold(
            appBar: AppBar(
              title: const Text('QCSR - Analytics Dashboard'),
              backgroundColor: Colors.indigo.shade800,
              bottom: TabBar(
                isScrollable: true,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                tabs: [
                  const Tab(icon: Icon(Icons.dashboard_outlined), text: 'Overview'),
                  const Tab(icon: Icon(Icons.people_outline), text: 'Operator Perf.'),
                  const Tab(icon: Icon(Icons.factory_outlined), text: 'Supplier & Location'),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.playlist_add),
                  tooltip: 'Seed Sample Data',
                  onPressed: () => _seedSampleData(context, firestoreService),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                  tooltip: 'Clear All Data',
                  onPressed: () => _showDeleteConfirmationDialog(context, firestoreService),
                ),
                IconButton(
                  icon: const Icon(Icons.table_chart),
                  tooltip: 'Export Excel',
                  onPressed: logs.isEmpty ? null : () => _exportExcel(context, excelExportService, logs),
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: 'Export PDF',
                  onPressed: logs.isEmpty ? null : () => pdfReportService.generateReport(logs),
                ),
              ],
            ),
            body: TabBarView(
              children: [
                _buildOverviewTab(context, snapshot, logs),
                _buildOperatorPerformanceTab(context, logs),
                _buildSupplierLocationTab(context, logs),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _seedSampleData(BuildContext context, FirestoreService firestoreService) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final now = DateTime.now();
      final List<SortingLog> sampleLogs = [
        SortingLog(
          partNo: 'PN-001',
          partName: 'Engine Bracket',
          quantitySorted: 500,
          quantityNg: 5,
          supplier: 'Tech-Corp',
          factoryLocation: 'Main Plant - Line 1',
          operators: ['Ali', 'Abu'],
          remarks: 'Minor burr found on edges.',
          ngDetails: [NgDetail(type: 'Burr', operatorName: 'Ali')],
          timestamp: Timestamp.fromDate(DateTime(now.year, now.month, now.day, 8, 30)),
        ),
        SortingLog(
          partNo: 'PN-002',
          partName: 'Brake Pad',
          quantitySorted: 450,
          quantityNg: 12,
          supplier: 'Auto-Parts Inc',
          factoryLocation: 'West Wing - Line 3',
          operators: ['Siti'],
          remarks: 'Surface cracks detected.',
          ngDetails: [NgDetail(type: 'Cracked', operatorName: 'Siti')],
          timestamp: Timestamp.fromDate(DateTime(now.year, now.month, now.day, 9, 15)),
        ),
        SortingLog(
          partNo: 'PN-001',
          partName: 'Engine Bracket',
          quantitySorted: 600,
          quantityNg: 2,
          supplier: 'Tech-Corp',
          factoryLocation: 'Main Plant - Line 1',
          operators: ['Ali'],
          remarks: 'Handling scratches.',
          ngDetails: [NgDetail(type: 'Scratched', operatorName: 'Ali')],
          timestamp: Timestamp.fromDate(DateTime(now.year, now.month, now.day, 10, 45)),
        ),
        SortingLog(
          partNo: 'PN-003',
          partName: 'Fuel Filter',
          quantitySorted: 300,
          quantityNg: 15,
          supplier: 'Global Components',
          factoryLocation: 'External Warehouse B',
          operators: ['Raju', 'Abu'],
          remarks: 'Seal failure.',
          ngDetails: [NgDetail(type: 'Leakage', operatorName: 'Raju')],
          timestamp: Timestamp.fromDate(DateTime(now.year, now.month, now.day, 11, 20)),
        ),
      ];

      for (var log in sampleLogs) {
        await firestoreService.addSortingLog(log);
      }

      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Sample data seeded successfully!')));
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error seeding data: $e')));
    }
  }

  void _showDeleteConfirmationDialog(BuildContext context, FirestoreService firestoreService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all sorting logs from the database. This action cannot be undone.',
          style: TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              try {
                await firestoreService.deleteAllLogs();
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('All data has been cleared.')),
                );
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Error clearing data: $e')),
                );
              }
            },
            child: const Text('Clear Everything'),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context, AsyncSnapshot<List<SortingLog>> snapshot, List<SortingLog> logs) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return Center(child: Text('Error: ${snapshot.error}'));
    }
    if (logs.isEmpty) {
      return const Center(child: Text('No logs found.'));
    }

    final totalSorted = logs.fold(0, (sum, log) => sum + log.quantitySorted);
    final totalNg = logs.fold(0, (sum, log) => sum + log.quantityNg);
    final ngRate = (totalSorted + totalNg) == 0 ? 0 : (totalNg / (totalSorted + totalNg)) * 100;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatCard('Total Sorted', totalSorted.toString(), context, Colors.indigo, Icons.inventory_2),
              _buildStatCard('Total NG', totalNg.toString(), context, Colors.red.shade700, Icons.report_problem),
              _buildStatCard('NG Rate', '${ngRate.toStringAsFixed(2)}%', context, Colors.amber.shade900, Icons.analytics),
            ],
          ),
          const SizedBox(height: 32),
          _buildDashboardSection(
            title: 'HOURLY PRODUCTION TREND',
            icon: Icons.show_chart,
            child: Container(
              height: 250,
              padding: const EdgeInsets.fromLTRB(16, 24, 24, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.indigo.withOpacity(0.1)),
              ),
              child: LineChart(_buildChartData(logs, context)),
            ),
          ),
          const SizedBox(height: 32),
          _buildDashboardSection(
            title: 'RECENT INSPECTION LOGS',
            icon: Icons.list_alt,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.indigo.withOpacity(0.1)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildLogsTable(logs, context),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildDashboardSection({required String title, required IconData icon, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.indigo.shade800),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo.shade900, letterSpacing: 1.2)),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildOperatorPerformanceTab(BuildContext context, List<SortingLog> logs) {
    if (logs.isEmpty) return const Center(child: Text('No data for performance analysis'));

    // Aggregate data by Operator -> Hour
    Map<String, Map<int, int>> operatorHourly = {};
    for (var log in logs) {
      final ops = log.operators.isEmpty ? ["Unknown"] : log.operators;
      final hour = log.timestamp.toDate().hour;
      final splitQty = (log.quantitySorted / ops.length).floor();

      for (var op in ops) {
        operatorHourly.putIfAbsent(op, () => {});
        operatorHourly[op]![hour] = (operatorHourly[op]![hour] ?? 0) + splitQty;
      }
    }

    List<String> operators = operatorHourly.keys.toList()..sort();
    
    // Get all unique hours present in the data
    Set<int> availableHours = {};
    for (var hourMap in operatorHourly.values) {
      availableHours.addAll(hourMap.keys);
    }
    List<int> sortedHours = availableHours.toList()..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLeaderboard(operators, operatorHourly, logs),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.indigo.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.timer_outlined, color: Colors.indigo),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'HOURLY SORTING PERFORMANCE (Individual/Split)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DataTable(
                headingRowHeight: 48,
                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                columns: [
                  const DataColumn(label: Text('Operator')),
                  ...sortedHours.map((h) => DataColumn(label: Text('${h.toString().padLeft(2, '0')}:00', style: const TextStyle(fontSize: 12)))),
                  const DataColumn(label: Text('Total OK', style: TextStyle(color: Colors.indigo))),
                ],
                rows: operators.map((op) {
                  int opTotal = operatorHourly[op]!.values.fold(0, (a, b) => a + b);
                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.account_circle, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(op, style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      ...sortedHours.map((h) {
                        int val = operatorHourly[op]![h] ?? 0;
                        return DataCell(
                          Container(
                            width: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            decoration: val > 0
                                ? BoxDecoration(
                                    color: val > 200 ? Colors.indigo.withOpacity(0.15) : Colors.indigo.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(4),
                                  )
                                : null,
                            alignment: Alignment.center,
                            child: Text(
                              val == 0 ? '-' : val.toString(),
                              style: TextStyle(
                                fontWeight: val > 200 ? FontWeight.bold : FontWeight.normal,
                                color: val > 0 ? Colors.indigo : Colors.grey,
                              ),
                            ),
                          ),
                        );
                      }),
                      DataCell(
                        Text(
                          opTotal.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 16),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 30),
          _buildPerformanceInsights(operators, operatorHourly),
        ],
      ),
    );
  }

  Widget _buildSupplierLocationTab(BuildContext context, List<SortingLog> logs) {
    if (logs.isEmpty) return const Center(child: Text('No data for location analysis'));

    // Grouping by Supplier
    Map<String, int> supplierTotal = {};
    Map<String, int> locationTotal = {};

    for (var log in logs) {
      supplierTotal.update(log.supplier, (v) => v + log.quantitySorted, ifAbsent: () => log.quantitySorted);
      locationTotal.update(log.factoryLocation, (v) => v + log.quantitySorted, ifAbsent: () => log.quantitySorted);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.business, 'Production by Supplier'),
          const SizedBox(height: 8),
          _buildSummaryTable(supplierTotal, 'Supplier Name'),
          const SizedBox(height: 32),
          _buildSectionHeader(Icons.location_on, 'Production by Factory Location'),
          const SizedBox(height: 8),
          _buildSummaryTable(locationTotal, 'Location / Line'),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.indigo, size: 20),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo, letterSpacing: 1.1)),
        ],
      ),
    );
  }

  Widget _buildSummaryTable(Map<String, int> data, String label) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.withOpacity(0.1)),
      ),
      child: DataTable(
        headingRowHeight: 40,
        headingRowColor: WidgetStateProperty.all(Colors.indigo.withOpacity(0.02)),
        columns: [
          DataColumn(label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo))),
          const DataColumn(label: Text('TOTAL OK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo)), numeric: true),
        ],
        rows: data.entries.map((e) => DataRow(cells: [
          DataCell(Text(e.key.isEmpty ? "Not Specified" : e.key, style: const TextStyle(fontSize: 13))),
          DataCell(Text(e.value.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 13))),
        ])).toList(),
      ),
    );
  }

  Widget _buildPerformanceInsights(List<String> operators, Map<String, Map<int, int>> data) {
    return Card(
      color: Colors.blueGrey[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.insights, color: Colors.blueGrey),
                SizedBox(width: 8),
                Text('Performance Insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            ...operators.map((op) {
              final hours = data[op]!;
              if (hours.isEmpty) return Container();
              int peakVal = 0;
              int peakHour = 0;
              hours.forEach((h, v) {
                if (v > peakVal) {
                  peakVal = v;
                  peakHour = h;
                }
              });
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('• $op peak performance at ${peakHour.toString().padLeft(2, '0')}:00 ($peakVal units)'),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, BuildContext context, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  LineChartData _buildChartData(List<SortingLog> logs, BuildContext context) {
    final Map<int, double> hourlyData = {};
    for (var log in logs) {
      final hour = log.timestamp.toDate().hour;
      hourlyData.update(hour, (value) => value + log.quantitySorted, ifAbsent: () => log.quantitySorted.toDouble());
    }

    final List<FlSpot> spots = hourlyData.entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value);
    }).toList()..sort((a, b) => a.x.compareTo(b.x));

    return LineChartData(
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (spot) => Colors.indigo.withOpacity(0.8),
          getTooltipItems: (spots) => spots.map((s) => LineTooltipItem('${s.y.toInt()} units', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))).toList(),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
          isCurved: true,
          curveSmoothness: 0.35,
          color: Colors.indigo.shade700,
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
              radius: 4,
              color: Colors.white,
              strokeWidth: 2,
              strokeColor: Colors.indigo.shade700,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [Colors.indigo.withOpacity(0.3), Colors.indigo.withOpacity(0.01)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (val, meta) => Text(val.toInt().toString(), style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: (val, meta) => Text('${val.toInt().toString().padLeft(2, '0')}:00', style: TextStyle(color: Colors.grey.shade600, fontSize: 9)),
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
    );
  }

  Widget _buildLogsTable(List<SortingLog> logs, BuildContext context) {
    return DataTable(
      headingRowHeight: 45,
      headingRowColor: WidgetStateProperty.all(Colors.indigo.shade50.withOpacity(0.5)),
      horizontalMargin: 16,
      columnSpacing: 24,
      columns: [
        const DataColumn(label: Text('TEAM / OPERATORS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.indigo))),
        const DataColumn(label: Text('PART NAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.indigo))),
        const DataColumn(label: Text('QTY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.indigo))),
        const DataColumn(label: Text('NG DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.indigo))),
      ],
      rows: logs.take(20).map((log) {
        String ops = log.operators.join(", ");
        if (ops.isEmpty) ops = "None";
        
        String ngSummary = log.ngDetails.map((e) => "${e.type}").join(", ");
        if (ngSummary.isEmpty) ngSummary = "None";
        
        return DataRow(
          cells: [
            DataCell(
              Tooltip(
                message: ops,
                child: Row(
                  children: [
                    const Icon(Icons.people_outline, size: 14, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      ops.length > 30 ? "${ops.substring(0, 27)}..." : ops,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            DataCell(Text(log.partName, style: const TextStyle(fontSize: 12))),
            DataCell(Text(log.quantitySorted.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo))),
            DataCell(
              Tooltip(
                message: ngSummary,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ngSummary == "None" ? Colors.transparent : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    ngSummary.length > 20 ? "${ngSummary.substring(0, 17)}..." : ngSummary,
                    style: TextStyle(
                      color: ngSummary == "None" ? Colors.grey : Colors.red.shade700,
                      fontSize: 11,
                      fontWeight: ngSummary == "None" ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildLeaderboard(List<String> operators, Map<String, Map<int, int>> data, List<SortingLog> logs) {
    if (operators.isEmpty) return Container();

    // Find overall top operator (Volume)
    String topOp = "";
    int maxVol = -1;
    
    // Find Operator with lowest NG rate (Quality - min 100 units)
    String qualityOp = "";
    double minNgRate = 100.0;

    Map<String, int> opTotalOk = {};
    Map<String, int> opTotalNg = {};

    for (var op in operators) {
      int ok = data[op]!.values.fold(0, (a, b) => a + b);
      opTotalOk[op] = ok;
      if (ok > maxVol) {
        maxVol = ok;
        topOp = op;
      }
    }

    for (var log in logs) {
      final ops = log.operators.isEmpty ? ["Unknown"] : log.operators;
      final splitNg = (log.quantityNg / ops.length).floor();
      for (var op in ops) {
        opTotalNg[op] = (opTotalNg[op] ?? 0) + splitNg;
      }
    }

    opTotalOk.forEach((op, ok) {
      if (ok >= 100) { // Minimum threshold for quality award
        int ng = opTotalNg[op] ?? 0;
        double rate = (ok + ng) == 0 ? 0 : (ng / (ok + ng)) * 100;
        if (rate < minNgRate) {
          minNgRate = rate;
          qualityOp = op;
        }
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CURRENT LEADERS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.indigo)),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildLeaderCard('TOP PRODUCER', topOp, '$maxVol Units', Colors.indigo.shade800, Icons.workspace_premium),
            const SizedBox(width: 12),
            _buildLeaderCard('QUALITY CHAMP', qualityOp.isEmpty ? 'N/A' : qualityOp, 
              qualityOp.isEmpty ? '-' : '${minNgRate.toStringAsFixed(2)}% NG', Colors.blueGrey.shade800, Icons.verified),
          ],
        ),
      ],
    );
  }

  Widget _buildLeaderCard(String label, String name, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                Icon(icon, color: Colors.white, size: 16),
              ],
            ),
            const SizedBox(height: 8),
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            Text(value, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  void _exportExcel(BuildContext context, ExcelExportService service, List<SortingLog> logs) async {
    try {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Generating Excel report...'), duration: Duration(seconds: 1)),
      );
      
      final filePath = await service.generateExcelReport(logs);
      
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Excel report saved to:\n$filePath'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating Excel: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
