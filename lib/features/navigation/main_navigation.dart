import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:movieswipe/core/providers/auth_provider.dart';
import 'package:movieswipe/core/providers/liked_movies_provider.dart';
import 'package:movieswipe/features/movies/presentation/pages/swipe_page.dart';
import 'package:movieswipe/features/movies/presentation/pages/my_list_page.dart';
import 'package:movieswipe/features/users/presentation/pages/profile_page.dart';
import 'package:movieswipe/core/di/injection_container.dart';
import 'package:movieswipe/core/presentation/widgets/global_app_background.dart';

import 'package:movieswipe/features/movies/presentation/bloc/movies_bloc.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_event.dart';
import 'package:movieswipe/features/social/presentation/bloc/social_bloc.dart';

/// Main navigation scaffold with bottom navigation bar
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    SwipePage(),
    MyListPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = Provider.of<AuthProvider>(context, listen: false).currentUserId;
      if (userId != null) {
        Provider.of<LikedMoviesProvider>(context, listen: false).loadFromApi(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<MoviesBloc>()..add(LoadMoviesEvent())),
        BlocProvider(create: (_) => sl<SocialBloc>()),
      ],
      child: GlobalAppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          bottomNavigationBar: NavigationBar(
            backgroundColor: Colors.transparent,
            indicatorColor: Colors.white.withValues(alpha: 0.1),
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
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
      ),
    );
  }
}

