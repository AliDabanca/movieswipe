import 'package:flutter/material.dart';
import 'package:movieswipe/core/config/env_config.dart';
import 'package:movieswipe/core/di/injection_container.dart' as di;
import 'package:movieswipe/features/movies/presentation/pages/swipe_page.dart';

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
    return MaterialApp(
      title: 'MovieSwipe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SwipePage(),
    );
  }
}
