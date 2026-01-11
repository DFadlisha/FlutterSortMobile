import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/models/sorting_log.dart';
import 'package:myapp/services/firestore_service.dart';
import 'package:myapp/services/pdf_report_service.dart';

class ManagementDashboard extends StatelessWidget {
  const ManagementDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();
    final PdfReportService pdfReportService = PdfReportService();

    return StreamBuilder<List<SortingLog>>(
      stream: firestoreService.getSortingLogs(),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('QCSR - Management Dashboard'),
            actions: [
              IconButton(
                icon: const Icon(Icons.playlist_add),
                tooltip: 'Seed Sample Data',
                onPressed: () async {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  try {
                    final now = DateTime.now();
                    final List<SortingLog> sampleLogs = [
                      SortingLog(
                        partNo: 'PN-001',
                        partName: 'Engine Bracket',
                        quantitySorted: 500,
                        quantityNg: 5,
                        ngType: 'Burr',
                        operatorName: 'Ali',
                        supplier: 'Factory A',
                        timestamp: Timestamp.fromDate(now.subtract(const Duration(hours: 8))),
                      ),
                      SortingLog(
                        partNo: 'PN-002',
                        partName: 'Brake Pad',
                        quantitySorted: 450,
                        quantityNg: 12,
                        ngType: 'Cracked',
                        operatorName: 'Siti',
                        supplier: 'Factory B',
                        timestamp: Timestamp.fromDate(now.subtract(const Duration(hours: 6))),
                      ),
                      SortingLog(
                        partNo: 'PN-001',
                        partName: 'Engine Bracket',
                        quantitySorted: 600,
                        quantityNg: 2,
                        ngType: 'Scratched',
                        operatorName: 'Ali',
                        supplier: 'Factory A',
                        timestamp: Timestamp.fromDate(now.subtract(const Duration(hours: 4))),
                      ),
                      SortingLog(
                        partNo: 'PN-003',
                        partName: 'Fuel Filter',
                        quantitySorted: 300,
                        quantityNg: 15,
                        ngType: 'Leakage',
                        operatorName: 'Raju',
                        supplier: 'Factory C',
                        timestamp: Timestamp.fromDate(now.subtract(const Duration(hours: 2))),
                      ),
                      SortingLog(
                        partNo: 'PN-002',
                        partName: 'Brake Pad',
                        quantitySorted: 550,
                        quantityNg: 8,
                        ngType: 'Rust',
                        operatorName: 'Siti',
                        supplier: 'Factory B',
                        timestamp: Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
                      ),
                    ];

                    for (var log in sampleLogs) {
                      await firestoreService.addSortingLog(log);
                    }

                    // Seed sample parts for scanning test
                    final partsMaster = FirebaseFirestore.instance.collection('parts_master');
                    await partsMaster.doc('PN-001').set({'part_name': 'Engine Bracket'});
                    await partsMaster.doc('PN-002').set({'part_name': 'Brake Pad'});
                    await partsMaster.doc('PN-003').set({'part_name': 'Fuel Filter'});

                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('Sample data and parts seeded successfully!')),
                    );
                  } catch (e) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('Error seeding data: $e')),
                    );
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                tooltip: 'Export Report',
                onPressed: logs.isEmpty
                    ? null
                    : () async {
                        await pdfReportService.generateReport(logs);
                      },
              ),
            ],
          ),
          body: () {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No logs found.'));
            }

            final totalSorted = logs.fold(0, (previousValue, log) => previousValue + log.quantitySorted);
            final totalNg = logs.fold(0, (previousValue, log) => previousValue + log.quantityNg);
            final ngRate = totalSorted == 0 ? 0 : (totalNg / (totalSorted + totalNg)) * 100;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard('Total Sorted', totalSorted.toString(), context),
                      _buildStatCard('Total NG', totalNg.toString(), context),
                      _buildStatCard('NG Rate', '${ngRate.toStringAsFixed(2)}%', context),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Hourly Production Trend', style: Theme.of(context).textTheme.titleLarge),
                  SizedBox(
                    height: 200,
                    child: LineChart(_buildChartData(logs, context)),
                  ),
                  const SizedBox(height: 24),
                  Text('Recent Logs', style: Theme.of(context).textTheme.titleLarge),
                  _buildLogsTable(logs, context),
                ],
              ),
            );
          }(),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
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
  }).toList();

  return LineChartData(
    lineBarsData: [
      LineChartBarData(
        spots: spots,
        isCurved: true,
        color: Theme.of(context).colorScheme.primary,
        barWidth: 3,
        belowBarData: BarAreaData(show: true, color: Theme.of(context).colorScheme.primary.withAlpha(50)),
      ),
    ],
    titlesData: const FlTitlesData(
      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
    ),
    gridData: const FlGridData(show: true),
    borderData: FlBorderData(show: true),
  );
}


  Widget _buildLogsTable(List<SortingLog> logs, BuildContext context) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Operator')),
        DataColumn(label: Text('Part Name')),
        DataColumn(label: Text('Sorted')),
        DataColumn(label: Text('NG')),
      ],
      rows: logs.take(10).map((log) {
        return DataRow(
          cells: [
            DataCell(Text(log.operatorName)),
            DataCell(Text(log.partName)),
            DataCell(Text(log.quantitySorted.toString())),
            DataCell(Text(log.quantityNg.toString())),
          ],
        );
      }).toList(),
    );
  }
}
