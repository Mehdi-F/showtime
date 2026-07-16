import 'package:flutter/material.dart';
import '../widgets/offline_banner.dart';
import 'series_screen.dart';
import 'films_screen.dart';
import 'search_screen.dart';
import 'profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [
    ProfileScreen(),
    SeriesScreen(),
    FilmsScreen(),
    SearchScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: IndexedStack(index: _index, children: _screens)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
          NavigationDestination(icon: Icon(Icons.tv_outlined), label: 'Séries'),
          NavigationDestination(icon: Icon(Icons.movie_outlined), label: 'Films'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Explorer'),
        ],
      ),
    );
  }
}
