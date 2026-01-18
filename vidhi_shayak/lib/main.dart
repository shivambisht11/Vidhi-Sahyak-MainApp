import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'firebase_options.dart';
import 'core/app_theme.dart';

// by shivam bisht

// Screens
import 'screens/onboarding_screen.dart';
import 'screens/category_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';

// Theme State Globa
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
// Locale State Global
final ValueNotifier<Locale> localeNotifier = ValueNotifier(const Locale('en'));

// Navigator Key removed as we don't need resume splash anymore
// final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebasechat
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final prefs = await SharedPreferences.getInstance();
  final onboardingComplete = prefs.getBool("onboarding_complete") ?? false;
  final userCategory = prefs.getString("user_category");

  // Load saved theme preference
  final isDark = prefs.getBool("is_dark_mode") ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  // Load saved language preference
  final savedLanguage = prefs.getString('language_code') ?? 'en';
  localeNotifier.value = Locale(savedLanguage);

  runApp(
    VidhiShayak(
      showOnboarding: !onboardingComplete,
      userCategory: userCategory,
    ),
  );
}

class VidhiShayak extends StatefulWidget {
  final bool showOnboarding;
  final String? userCategory;

  const VidhiShayak({
    super.key,
    required this.showOnboarding,
    this.userCategory,
  });

  @override
  State<VidhiShayak> createState() => _VidhiShayakState();
}

class _VidhiShayakState extends State<VidhiShayak> {
  // Lifecycle methods removed to stop Splash on Resume.
  // Now it only shows on Cold Start (initial Launch).

  @override
  Widget build(BuildContext context) {
    Widget homeScreen;

    if (widget.showOnboarding) {
      homeScreen = const OnboardingScreen();
    } else if (widget.userCategory != null) {
      homeScreen = HomeScreen(selectedCategory: widget.userCategory!);
    } else {
      homeScreen = const CategoryScreen();
    }

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return ValueListenableBuilder<Locale>(
          valueListenable: localeNotifier,
          builder: (context, locale, _) {
            return MaterialApp(
              // navigatorKey removed
              title: "VidhiShayak",
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: currentMode,
              locale: locale,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('en'), // English
                Locale('hi'), // Hindi
              ],
              debugShowCheckedModeBanner: false,
              // Start with Splash Screen, pass resolved homeScreen as next destination
              home: SplashScreen(nextScreen: homeScreen),
              routes: {'/login': (_) => const LoginScreen()},
            );
          },
        );
      },
    );
  }
}
