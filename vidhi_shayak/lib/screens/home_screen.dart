import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart'; // Import
import '../core/app_theme.dart';
import 'chat_screen.dart';
import 'hiring_updates_screen.dart';

class HomeScreen extends StatefulWidget {
  final String selectedCategory;

  const HomeScreen({super.key, required this.selectedCategory});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      ChatScreen(selectedCategory: widget.selectedCategory),
      const HiringUpdatesScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor, // Dynamic color
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Theme.of(context).cardColor, // Dynamic color
          selectedItemColor: AppTheme.primaryColor,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              activeIcon: const Icon(Icons.chat_bubble_rounded),
              label: l10n.navChat,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.work_outline_rounded),
              activeIcon: const Icon(Icons.work_rounded),
              label: l10n.navHiring,
            ),
          ],
        ),
      ),
    );
  }
}
