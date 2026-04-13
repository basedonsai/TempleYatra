import 'package:flutter/material.dart';
import '../database/repositories/settings_repository.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'profile_setup_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Future<void> _proceed(BuildContext context) async {
    final settings = const SettingsRepository();
    await settings.setHasOnboarded(true);
    if (!context.mounted) return;

    final profileDone = await settings.profileSetupDone;
    if (!context.mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => profileDone ? const HomeScreen() : const ProfileSetupScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.saffron.withValues(alpha: 0.1),
              AppTheme.sandalwoodBeige,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.saffron,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.saffron.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.temple_hindu, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 32),
                Text(
                  'TempleYatra',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: AppTheme.maroon,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your AI-powered temple travel companion',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.deepMaroon.withValues(alpha: 0.8),
                      ),
                ),
                const Spacer(flex: 3),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _proceed(context),
                    icon: const Icon(Icons.explore),
                    label: const Text('Get Started'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.maroon,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => _proceed(context),
                    child: Text(
                      'Continue as Guest',
                      style: TextStyle(color: AppTheme.maroon.withValues(alpha: 0.7)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
