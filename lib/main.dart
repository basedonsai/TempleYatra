import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'providers/audio_pack_provider.dart';
import 'database/app_database.dart';
import 'database/database_seeder.dart';
import 'database/repositories/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // ── SQLite init + seed ──────────────────────────────────────────────────
  await AppDatabase.instance.db; // opens & creates tables
  await DatabaseSeeder.seedIfNeeded();

  // ── Onboarding flag (now from SQLite, SharedPreferences as fallback) ────
  final settings = const SettingsRepository();
  bool hasOnboarded = await settings.hasOnboarded;

  // Migrate existing SharedPreferences flag on first run after upgrade
  if (!hasOnboarded) {
    final prefs = await SharedPreferences.getInstance();
    final legacyFlag = prefs.getBool('has_onboarded') ?? false;
    if (legacyFlag) {
      await settings.setHasOnboarded(true);
      hasOnboarded = true;
    }
  }

  // SharedPreferences still needed for AudioPackService (Phase 2 will remove this)
  final prefs = await SharedPreferences.getInstance();

  runApp(TempleYatraApp(prefs: prefs, hasOnboarded: hasOnboarded));
}

class TempleYatraApp extends StatelessWidget {
  final SharedPreferences prefs;
  final bool hasOnboarded;
  const TempleYatraApp({super.key, required this.prefs, required this.hasOnboarded});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        title: 'TempleYatra - Your Spiritual Journey Companion',
        theme: AppTheme.theme,
        debugShowCheckedModeBanner: false,
        home: hasOnboarded ? const HomeScreen() : const OnboardingScreen(),
        scrollBehavior: _WebScrollBehavior(),
      ),
    );
  }
}

class _WebScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return GlowingOverscrollIndicator(
      child: child,
      axisDirection: details.direction,
      color: AppTheme.saffron,
    );
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 768;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 768 &&
      MediaQuery.of(context).size.width < 1200;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1200;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200 && desktop != null) return desktop!;
    if (width >= 768 && tablet != null) return tablet!;
    return mobile;
  }
}

class MaxWidthContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const MaxWidthContainer({
    super.key,
    required this.child,
    this.maxWidth = 1200,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
