import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/offline_banner.dart';
import '../l10n/localization_context.dart';
import '../providers/settings_provider.dart';
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
    context.watch<SettingsProvider>(); // Rebuild on language change
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
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
        destinations: [
          NavigationDestination(icon: const Icon(Icons.tv_outlined), label: context.tr('nav.series')),
          NavigationDestination(icon: const Icon(Icons.movie_outlined), label: context.tr('nav.films')),
          NavigationDestination(icon: const Icon(Icons.search), label: context.tr('nav.explore')),
          NavigationDestination(icon: const Icon(Icons.person_outline), label: context.tr('nav.profile')),
        ],
      ),
    );
  }
}
