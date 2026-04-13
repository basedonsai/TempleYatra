import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/db_providers.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'profile_setup_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) => _ProfileBody(user: user),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  final UserProfile user;
  const _ProfileBody({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = avatarColor(user.avatarSeed);
    final isGuest = user.role == UserRole.guest;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 16),

        // Avatar
        CircleAvatar(
          radius: 48,
          backgroundColor: color,
          child: Text(
            user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
            style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),

        // Name
        Text(user.displayName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),

        // Role badge
        _RolePill(role: user.role),
        const SizedBox(height: 32),

        // Guest prompt
        if (isGuest)
          Card(
            color: AppTheme.saffron.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Icon(Icons.info_outline, color: AppTheme.saffron),
                const SizedBox(height: 8),
                const Text('You are browsing as a guest.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Create a profile to post stories and interact with the community.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.maroon,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Create Profile'),
                ),
              ]),
            ),
          )
        else ...[
          // Edit profile button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileSetupScreen(isEditing: true)),
              ),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Profile'),
            ),
          ),
          const SizedBox(height: 12),
        ],

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

        // Info rows
        _InfoRow(icon: Icons.badge_outlined, label: 'Role', value: user.role.label),
        _InfoRow(
          icon: Icons.calendar_today_outlined,
          label: 'Member since',
          value: '${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}',
        ),

        const SizedBox(height: 32),

        // Reset to guest (non-destructive — just clears current user id)
        if (!isGuest)
          TextButton(
            onPressed: () => _confirmReset(context, ref),
            child: Text('Sign out / Reset identity',
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ),
      ]),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset identity?'),
        content: const Text(
            'Your local posts and likes will remain, but your profile name and role will be cleared. You will become a guest.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(currentUserProvider.notifier).resetToGuest();
    }
  }
}

class _RolePill extends StatelessWidget {
  final UserRole role;
  const _RolePill({required this.role});

  @override
  Widget build(BuildContext context) {
    final (color, bg, icon) = switch (role) {
      UserRole.admin => (AppTheme.maroon, AppTheme.maroon.withValues(alpha: 0.1), Icons.shield_outlined),
      UserRole.local => (Colors.amber[800]!, Colors.amber.withValues(alpha: 0.12), Icons.location_city),
      UserRole.pilgrim => (Colors.teal[700]!, Colors.teal.withValues(alpha: 0.1), Icons.directions_walk),
      UserRole.guest => (Colors.grey[600]!, Colors.grey.withValues(alpha: 0.1), Icons.person_outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(role.label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, size: 20, color: Colors.grey[500]),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ]),
    );
  }
}
