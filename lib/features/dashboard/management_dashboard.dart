import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/models/sorting_log.dart';
import 'package:myapp/services/firestore_service.dart';
import 'package:myapp/services/excel_export_service.dart';
import 'package:myapp/theme/app_colors.dart';

class ManagementDashboard extends StatelessWidget {
  const ManagementDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();
    final ExcelExportService excelExportService = ExcelExportService();

    return DefaultTabController(
      length: 2,
      child: StreamBuilder<List<SortingLog>>(
        stream: firestoreService.getSortingLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF1A1F3A),
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              backgroundColor: const Color(0xFF1A1F3A),
              body: Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white))),
            );
          }

          final logs = snapshot.data ?? [];

          return Scaffold(
            appBar: AppBar(
              elevation: 0,
              title: const Text('QCSR - Operator Output', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              iconTheme: const IconThemeData(color: Colors.white),
              bottom: TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                indicatorColor: AppColors.primaryPurple,
                indicatorWeight: 4,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                tabs: const [
                  Tab(icon: Icon(Icons.analytics_outlined), text: 'OVERVIEW'),
                  Tab(icon: Icon(Icons.speed), text: 'OPERATOR PERFORMANCE'),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.table_chart, color: Colors.white),
                  tooltip: 'Export Excel',
                  onPressed: logs.isEmpty ? null : () => _exportExcel(context, excelExportService, logs),
                ),
              ],
            ),
            body: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: TabBarView(
                children: [
                  _buildOverviewTab(context, snapshot, logs),
                  _buildOperatorPerformanceTab(context, logs),
                ],
              ),
            ),
          );
        },
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
                color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryPurple.withOpacity(0.3)),
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
                color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryPurple.withOpacity(0.3)),
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
            Icon(icon, size: 20, color: AppColors.primaryPurple),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
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
              color: AppColors.primaryPurple.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primaryPurple.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.timer_outlined, color: AppColors.primaryPurple),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'HOURLY SORTING PERFORMANCE (Individual/Split)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
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
                side: BorderSide(color: AppColors.primaryPurple.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DataTable(
                headingRowHeight: 48,
                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                columns: [
                  const DataColumn(label: Text('Operator', style: TextStyle(color: Colors.white70))),
                  ...sortedHours.map((h) => DataColumn(label: Text('${h.toString().padLeft(2, '0')}:00', style: const TextStyle(fontSize: 12, color: Colors.white70)))),
                  const DataColumn(label: Text('Total OK', style: TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold))),
                ],
                rows: operators.map((op) {
                  int opTotal = operatorHourly[op]!.values.fold(0, (a, b) => a + b);
                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.account_circle, size: 16, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(op, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
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
                                    color: val > 200 ? AppColors.primaryPurple.withOpacity(0.2) : AppColors.primaryPurple.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(4),
                                  )
                                : null,
                            alignment: Alignment.center,
                            child: Text(
                              val == 0 ? '-' : val.toString(),
                              style: TextStyle(
                                fontWeight: val > 200 ? FontWeight.bold : FontWeight.w600,
                                color: val > 0 ? Colors.white : Colors.white38,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }),
                      DataCell(
                        Text(
                          opTotal.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryPurple, fontSize: 16),
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


  Widget _buildPerformanceInsights(List<String> operators, Map<String, Map<int, int>> data) {
    return Card(
      color: const Color(0xFF2D3561),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.primaryPurple.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.insights, color: AppColors.primaryPurple),
                SizedBox(width: 8),
                Text('Performance Insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            const Divider(color: Colors.white24),
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
                child: Text('• $op peak performance at ${peakHour.toString().padLeft(2, '0')}:00 ($peakVal units)', style: const TextStyle(color: Colors.white70)),
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: Theme.of(context).brightness == Brightness.dark 
                ? [AppColors.darkCard, AppColors.darkSurface]
                : [Colors.white, AppColors.lightCard],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
          ],
          border: Border.all(color: AppColors.primaryPurple.withOpacity(0.3)),
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
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryPurple)),
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
          getTooltipColor: (spot) => AppColors.primaryPurple.withOpacity(0.9),
          getTooltipItems: (spots) => spots.map((s) => LineTooltipItem('${s.y.toInt()} units', const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))).toList(),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
          isCurved: true,
          curveSmoothness: 0.35,
          color: AppColors.primaryPurple,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
              radius: 5,
              color: AppColors.primaryPurple,
              strokeWidth: 2,
              strokeColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [AppColors.primaryPurple.withOpacity(0.3), AppColors.primaryPurple.withOpacity(0.01)],
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
            getTitlesWidget: (val, meta) => Text(val.toInt().toString(), style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: (val, meta) => Text('${val.toInt().toString().padLeft(2, '0')}:00', style: const TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withOpacity(0.1), strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
    );
  }

  Widget _buildLogsTable(List<SortingLog> logs, BuildContext context) {
    return DataTable(
      headingRowHeight: 45,
      headingRowColor: WidgetStateProperty.all(Colors.white.withOpacity(0.05)),
      horizontalMargin: 16,
      columnSpacing: 24,
      columns: [
        const DataColumn(label: Text('TEAM / OPERATORS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white))),
        const DataColumn(label: Text('PART NAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white))),
        const DataColumn(label: Text('QTY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white))),
        const DataColumn(label: Text('NG DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white))),
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
                    const Icon(Icons.people_outline, size: 14, color: Colors.white70),
                    const SizedBox(width: 8),
                    Text(
                      ops.length > 30 ? "${ops.substring(0, 27)}..." : ops,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            DataCell(Text(log.partName, style: const TextStyle(fontSize: 12, color: Colors.white))),
            DataCell(Text(log.quantitySorted.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryPurple))),
            DataCell(
              Tooltip(
                message: ngSummary,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ngSummary == "None" ? Colors.transparent : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    ngSummary.length > 20 ? "${ngSummary.substring(0, 17)}..." : ngSummary,
                    style: TextStyle(
                      color: ngSummary == "None" ? Colors.white60 : Colors.redAccent,
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
        const Text('CURRENT LEADERS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white)),
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
