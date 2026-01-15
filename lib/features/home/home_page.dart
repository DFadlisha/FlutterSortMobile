import 'package:flutter/material.dart';
import 'package:myapp/features/dashboard/management_dashboard.dart';
import 'package:myapp/features/scan/quality_scan_page.dart';
import 'package:myapp/features/hourly/hourly_output_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    HourlyOutputPage(),
    QualityScanPage(),
    ManagementDashboard(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1C1A45),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF7B61FF),
        unselectedItemColor: Colors.white60,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'Hourly',
            tooltip: 'Hourly Output',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'Report',
            tooltip: 'Quality Report',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assessment),
            label: 'Data',
            tooltip: 'View Data',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
