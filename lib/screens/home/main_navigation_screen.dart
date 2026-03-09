import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// Main navigation screen with persistent bottom navigation bar
/// Manages tab switching between Home and Profile screens
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  // List of screens to display based on selected tab
  static const List<Widget> _screens = [HomeScreen(), ProfileScreen()];

  void _onBottomNavTap(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(
              color: AppColors.primaryAccent.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primaryAccent,
          unselectedItemColor: AppColors.textSecondary,
          currentIndex: _selectedIndex,
          onTap: _onBottomNavTap,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: GoogleFonts.rajdhani(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.rajdhani(fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
