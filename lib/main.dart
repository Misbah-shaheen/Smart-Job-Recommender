// main.dart
// Entry point: initializes Firebase, sets up Provider, routes to auth or home.

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'services/app_provider.dart';
import 'utils/app_theme.dart';
import 'utils/app_constants.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase using the google-services.json / GoogleService-Info.plist
  // that you placed in android/app/ and ios/Runner/ respectively.
  await Firebase.initializeApp();

  runApp(
    // Provide AppProvider to the entire widget tree
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const SmartJobApp(),
    ),
  );
}

class SmartJobApp extends StatelessWidget {
  const SmartJobApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // Listen to auth state — show Login or Home screen accordingly
      home: Consumer<AppProvider>(
        builder: (context, provider, _) {
          if (provider.isLoggedIn) {
            return const HomeScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
