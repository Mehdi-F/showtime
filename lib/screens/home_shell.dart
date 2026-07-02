import 'package:flutter/material.dart';
import 'up_next_screen.dart';
import 'calendar_screen.dart';
import 'search_screen.dart';
import 'library_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [
    UpNextScreen(),
    CalendarScreen(),
    SearchScreen(),
    LibraryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.play_circle_outline), label: 'Up Next'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.video_library_outlined), label: 'Library'),
        ],
      ),
    );
  }
}
