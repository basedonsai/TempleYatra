import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/db_providers.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

// Fixed palette — avatarSeed % length picks the color
const _avatarColors = [
  Color(0xFFFF9933), Color(0xFF8B0000), Color(0xFF2E7D32),
  Color(0xFF1565C0), Color(0xFF6A1B9A), Color(0xFF00838F),
  Color(0xFFE65100), Color(0xFF37474F), Color(0xFFC62828),
  Color(0xFF4527A0),
];

Color avatarColor(int seed) => _avatarColors[seed % _avatarColors.length];

class ProfileSetupScreen extends ConsumerStatefulWidget {
  /// When true, this is an edit from ProfileScreen — show back button, no skip.
  final bool isEditing;
  const ProfileSetupScreen({super.key, this.isEditing = false});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameCtrl = TextEditingController();
  UserRole _role = UserRole.pilgrim;
  bool _saving = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    // Pre-fill when editing
    if (widget.isEditing) {
      ref.read(currentUserProvider.future).then((user) {
        if (mounted) {
          _nameCtrl.text = user.displayName;
          setState(() => _role = user.role == UserRole.guest ? UserRole.pilgrim : user.role);
        }
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  int get _avatarSeed => _nameCtrl.text.isEmpty ? 0 : _nameCtrl.text.codeUnits.first % 10;

  bool _validate() {
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      setState(() => _nameError = 'Name must be at least 2 characters');
      return false;
    }
    if (name.length > 30) {
      setState(() => _nameError = 'Name must be 30 characters or less');
      return false;
    }
    setState(() => _nameError = null);
    return true;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    await ref.read(currentUserProvider.notifier).setProfile(_nameCtrl.text.trim(), _role);
    if (!mounted) return;
    setState(() => _saving = false);
    if (widget.isEditing) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  Future<void> _skip() async {
    // Mark setup done without changing role — stays guest
    await ref.read(settingsRepositoryProvider).setProfileSetupDone(true);
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final seed = _avatarSeed;
    final color = avatarColor(seed);

    return Scaffold(
      appBar: widget.isEditing
          ? AppBar(title: const Text('Edit Profile'))
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!widget.isEditing) ...[
                const SizedBox(height: 32),
                Text('Create your profile',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppTheme.maroon,
                          fontWeight: FontWeight.bold,
                        )),
                const SizedBox(height: 8),
                Text('Tell us who you are so the community knows you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 32),
              ] else
                const SizedBox(height: 16),

              // Avatar preview
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 80,
                height: 80,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    _nameCtrl.text.isEmpty ? '?' : _nameCtrl.text[0].toUpperCase(),
                    style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Name field
              TextField(
                controller: _nameCtrl,
                maxLength: 30,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  hintText: 'e.g. Priya Sharma',
                  errorText: _nameError,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                onChanged: (_) => setState(() => _nameError = null),
              ),
              const SizedBox(height: 20),

              // Role picker
              Align(
                alignment: Alignment.centerLeft,
                child: Text('I am a…',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800])),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _RoleChip(
                    label: 'Pilgrim',
                    icon: Icons.directions_walk,
                    selected: _role == UserRole.pilgrim,
                    onTap: () => setState(() => _role = UserRole.pilgrim),
                    description: 'Visiting temples on a spiritual journey',
                  ),
                  const SizedBox(width: 12),
                  _RoleChip(
                    label: 'Local',
                    icon: Icons.location_city,
                    selected: _role == UserRole.local,
                    onTap: () => setState(() => _role = UserRole.local),
                    description: 'I live near these temples',
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.maroon,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(widget.isEditing ? 'Save Changes' : 'Save & Continue',
                          style: const TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),

              if (!widget.isEditing) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _saving ? null : _skip,
                  child: Text('Skip for now',
                      style: TextStyle(color: AppTheme.maroon.withValues(alpha: 0.6))),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String description;

  const _RoleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppTheme.maroon.withValues(alpha: 0.08) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.maroon : Colors.grey[300]!,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? AppTheme.maroon : Colors.grey[600], size: 28),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected ? AppTheme.maroon : Colors.grey[700],
                  )),
              const SizedBox(height: 4),
              Text(description,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
        ),
      ),
    );
  }
}
