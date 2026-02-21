import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:movieswipe/core/config/env_config.dart';
import 'package:movieswipe/core/di/injection_container.dart' as di;
import 'package:movieswipe/core/providers/auth_provider.dart';
import 'package:movieswipe/core/providers/liked_movies_provider.dart';
import 'package:movieswipe/features/auth/presentation/pages/login_page.dart';
import 'package:movieswipe/features/auth/presentation/pages/username_page.dart';
import 'package:movieswipe/features/navigation/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Get flavor from --dart-define
  const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');

  // Initialize environment configuration
  await EnvConfig.init(flavor: flavor);

  // Initialize Supabase
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
  );

  // Initialize dependency injection
  await di.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LikedMoviesProvider()),
      ],
      child: MaterialApp(
        title: 'MovieSwipe',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFe94560),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            // Still loading auth state
            if (auth.isLoading || (auth.isAuthenticated && !auth.profileChecked)) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            // Authenticated but no username yet → username selection
            if (auth.isAuthenticated && !auth.hasProfile) {
              return const UsernamePage();
            }
            // Authenticated with profile → main app
            if (auth.isAuthenticated && auth.hasProfile) {
              return const MainNavigation();
            }
            // Not authenticated → login
            return const LoginPage();
          },
        ),
      ),
    );
  }
}
