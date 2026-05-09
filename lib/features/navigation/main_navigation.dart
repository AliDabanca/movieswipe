import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:movieswipe/core/providers/auth_provider.dart';
import 'package:movieswipe/core/providers/liked_movies_provider.dart';
import 'package:movieswipe/core/theme/app_theme.dart';
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
          bottomNavigationBar: _buildGlassNavBar(),
        ),
      ),
    );
  }

  /// Premium frosted-glass bottom navigation bar
  Widget _buildGlassNavBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.midnight.withValues(alpha: 0.75),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            indicatorColor: AppTheme.accent.withValues(alpha: 0.12),
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.swipe_rounded,
                    color: Colors.white.withValues(alpha: 0.45)),
                selectedIcon: ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.primaryGradient.createShader(bounds),
                  child: const Icon(Icons.swipe_rounded, color: Colors.white),
                ),
                label: 'Keşfet',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_outline_rounded,
                    color: Colors.white.withValues(alpha: 0.45)),
                selectedIcon: ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.primaryGradient.createShader(bounds),
                  child: const Icon(Icons.favorite_rounded, color: Colors.white),
                ),
                label: 'Listem',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded,
                    color: Colors.white.withValues(alpha: 0.45)),
                selectedIcon: ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.primaryGradient.createShader(bounds),
                  child: const Icon(Icons.person_rounded, color: Colors.white),
                ),
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
