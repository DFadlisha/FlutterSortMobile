import 'package:flutter/material.dart';
import 'package:myapp/features/dashboard/management_dashboard.dart';
import 'package:myapp/features/scan/quality_scan_page.dart';
import 'package:myapp/features/hourly/hourly_output_page.dart';
import 'package:myapp/theme/app_colors.dart';

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
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? AppColors.darkSurface 
            : Colors.white,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primaryPurple,
        unselectedItemColor: Theme.of(context).brightness == Brightness.dark 
            ? Colors.white60 
            : Colors.black45,
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
