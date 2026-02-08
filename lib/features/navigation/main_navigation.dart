import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:movieswipe/core/providers/user_provider.dart';
import 'package:movieswipe/features/movies/presentation/pages/swipe_page.dart';
import 'package:movieswipe/features/movies/presentation/pages/my_list_page.dart';
import 'package:movieswipe/features/users/presentation/pages/profile_page.dart';
import 'package:movieswipe/core/di/injection_container.dart';

import 'package:movieswipe/features/movies/presentation/bloc/movies_bloc.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_event.dart';

/// Main navigation scaffold with bottom navigation bar
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  int _previousIndex = 0;
  final GlobalKey<MyListPageState> _myListKey = GlobalKey<MyListPageState>();
  final GlobalKey<ProfilePageState> _profileKey = GlobalKey<ProfilePageState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const SwipePage(),
      MyListPage(key: _myListKey),
      ProfilePage(key: _profileKey),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<MoviesBloc>()..add(LoadMoviesEvent()),
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _previousIndex = _currentIndex;
              _currentIndex = index;
            });
            
            // Refresh My List when leaving Swipe page (index 0) to My List (index 1)
            if (index == 1 && _previousIndex == 0) {
              print('🔄 Refreshing My List after session...');
              _myListKey.currentState?.refreshList();
            }

            // Refresh Profile when entering Profile page (index 2)
            if (index == 2) {
              print('🔄 Refreshing Profile stats...');
              _profileKey.currentState?.loadUserStats();
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.swipe),
              selectedIcon: Icon(Icons.swipe),
              label: 'Swipe',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_outline),
              selectedIcon: Icon(Icons.favorite),
              label: 'My List',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
