import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import '../theme/app_theme.dart';
import 'report_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const MapScreen(),
    const ReportScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('CityPulse'),
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return IconButton(
                icon: Icon(
                  themeProvider.themeMode == ThemeMode.dark
                      ? Icons.light_mode
                      : Icons.dark_mode,
                ),
                onPressed: () => themeProvider.toggleTheme(),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withOpacity(0.1),
                  AppTheme.secondaryColor.withOpacity(0.1),
                ],
              ),
            ),
          ),
          _screens[_selectedIndex],
        ],
      ),
      bottomNavigationBar: Theme(
        data: ThemeData(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: GlassmorphicContainer(
          width: 1.sw,
          height: 80.h,
          borderRadius: 20,
          blur: 10,
          alignment: Alignment.center,
          border: 0,
          linearGradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withOpacity(0.2),
              Colors.white.withOpacity(0.1),
            ],
          ),
          borderGradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.transparent,
            ],
          ),
          child: NavigationBar(
            height: 65.h,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.map_outlined,
                    color: _selectedIndex == 0
                        ? AppTheme.primaryColor
                        : Colors.grey),
                selectedIcon: Icon(Icons.map,
                    color: _selectedIndex == 0
                        ? AppTheme.primaryColor
                        : Colors.grey),
                label: 'Harita',
              ),
              NavigationDestination(
                icon: Icon(Icons.add_circle_outline,
                    color: _selectedIndex == 1
                        ? AppTheme.primaryColor
                        : Colors.grey),
                selectedIcon: Icon(Icons.add_circle,
                    color: _selectedIndex == 1
                        ? AppTheme.primaryColor
                        : Colors.grey),
                label: 'Bildir',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline,
                    color: _selectedIndex == 2
                        ? AppTheme.primaryColor
                        : Colors.grey),
                selectedIcon: Icon(Icons.person,
                    color: _selectedIndex == 2
                        ? AppTheme.primaryColor
                        : Colors.grey),
                label: 'Profil',
              ),
            ],
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            indicatorColor: AppTheme.primaryColor.withOpacity(0.1),
          ),
        ),
      ),
    );
  }
}
