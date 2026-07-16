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
  int _index = 3;
  late final Set<int> _visited = {_index};

  static const _screens = [
    SeriesScreen(),
    FilmsScreen(),
    SearchScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            // Screens are only built once their tab has actually been
            // visited — an IndexedStack alone builds every child up front
            // (it just hides the inactive ones), which meant Séries/Films
            // fetched their episode data on launch even when Profil was the
            // page shown. Kept in the stack (rather than swapped out) once
            // visited so their state and scroll position survive tab
            // switches.
            child: IndexedStack(
              index: _index,
              children: [
                for (var i = 0; i < _screens.length; i++)
                  _visited.contains(i) ? _screens[i] : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          _visited.add(i);
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.tv_outlined), label: 'Séries'),
          NavigationDestination(icon: Icon(Icons.movie_outlined), label: 'Films'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Explorer'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }
}
