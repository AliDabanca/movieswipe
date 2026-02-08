import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:movieswipe/core/config/env_config.dart';
import 'package:movieswipe/core/di/injection_container.dart' as di;
import 'package:movieswipe/core/providers/user_provider.dart';
import 'package:movieswipe/features/users/presentation/pages/user_selection_page.dart';
import 'package:movieswipe/features/navigation/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Get flavor from --dart-define (e.g., flutter run --dart-define=FLAVOR=dev)
  // Defaults to 'dev' if not specified
  const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');

  // Initialize environment configuration
  await EnvConfig.init(flavor: flavor);

  // Initialize dependency injection
  await di.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => UserProvider(),
      child: MaterialApp(
        title: 'MovieSwipe',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: Consumer<UserProvider>(
          builder: (context, userProvider, _) {
            // Show user selection if no user selected, otherwise show movies
            if (userProvider.currentUserId == null) {
              return const UserSelectionPage();
            }
            return const MainNavigation();
          },
        ),
      ),
    );
  }
}
