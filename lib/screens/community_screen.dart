import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/db_providers.dart';
import '../models/community_post.dart';
import '../models/user_profile.dart';

import '../theme/app_theme.dart';
import 'profile_setup_screen.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Community'),
          bottom: TabBar(
            tabs: [
              Tab(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.feed, size: 20),
                  const SizedBox(width: 6),
                  Text(isSmallScreen ? '' : 'Feed'),
                ]),
              ),
              Tab(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add_circle_outline, size: 20),
                  const SizedBox(width: 6),
                  Text(isSmallScreen ? '' : 'Contribute'),
                ]),
              ),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: TabBarView(
          children: [
            const _FeedTab(),
            _ContributeTab(),
          ],
        ),
      ),
    );
  }
}

// ── Feed tab ──────────────────────────────────────────────────────────────

class _FeedTab extends ConsumerWidget {
  const _FeedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(communityFeedProvider);
    final currentUserAsync = ref.watch(currentUserProvider);
    final currentUserId = currentUserAsync.valueOrNull?.id ?? '';
    final currentUserRole = currentUserAsync.valueOrNull?.role ?? UserRole.guest;

    return feedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text('Could not load feed', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => ref.invalidate(communityFeedProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ]),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text('No stories yet. Be the first to share!',
                  style: TextStyle(color: Colors.grey[600])),
            ]),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.read(communityFeedProvider.notifier).refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, i) => _PostCard(
              post: posts[i],
              currentUserId: currentUserId,
              currentUserRole: currentUserRole,
            ),
          ),
        );
      },
    );
  }
}

// ── Post card ─────────────────────────────────────────────────────────────

class _PostCard extends ConsumerWidget {
  final CommunityPost post;
  final String currentUserId;
  final UserRole currentUserRole;

  const _PostCard({
    required this.post,
    required this.currentUserId,
    required this.currentUserRole,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canDelete = post.authorId == currentUserId || currentUserRole.canDeleteAny;
    final avatarColor = avatarColor_(post.authorAvatarSeed);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: post.isPinned ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: post.isPinned
            ? BorderSide(color: AppTheme.saffron.withValues(alpha: 0.5), width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Pin indicator
          if (post.isPinned)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Icon(Icons.push_pin, size: 14, color: AppTheme.saffron),
                const SizedBox(width: 4),
                Text('Pinned', style: TextStyle(fontSize: 11, color: AppTheme.saffron, fontWeight: FontWeight.w600)),
              ]),
            ),

          // Author row
          Row(children: [
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: avatarColor,
              child: Text(
                post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(post.authorName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  _RoleBadge(role: post.authorRole),
                ]),
                Text(post.templeName,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ]),
            ),
            // Delete button (own posts or admin)
            if (canDelete)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                onPressed: () => _confirmDelete(context, ref),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ]),

          const SizedBox(height: 10),
          Text(post.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(post.body,
              style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
              maxLines: 4,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),

          // Category + date
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(post.category,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ),
            const Spacer(),
            Text(_formatDate(post.createdAt),
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ]),

          const Divider(height: 20),

          // Actions
          Row(children: [
            TextButton.icon(
              onPressed: () => ref.read(communityFeedProvider.notifier).toggleLike(post.id),
              icon: Icon(
                post.likedByMe ? Icons.thumb_up : Icons.thumb_up_outlined,
                size: 16,
                color: post.likedByMe ? AppTheme.saffron : Colors.grey,
              ),
              label: Text(
                post.likeCount > 0 ? '${post.likeCount}' : 'Like',
                style: TextStyle(
                  fontSize: 12,
                  color: post.likedByMe ? AppTheme.saffron : Colors.grey[600],
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Comments coming soon')),
              ),
              icon: const Icon(Icons.comment_outlined, size: 16, color: Colors.grey),
              label: Text('Comment', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(communityFeedProvider.notifier).deletePost(post.id);
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

Color avatarColor_(int seed) {
  const colors = [
    Color(0xFFFF9933), Color(0xFF8B0000), Color(0xFF2E7D32),
    Color(0xFF1565C0), Color(0xFF6A1B9A), Color(0xFF00838F),
    Color(0xFFE65100), Color(0xFF37474F), Color(0xFFC62828),
    Color(0xFF4527A0),
  ];
  return colors[seed % colors.length];
}

// ── Role badge ────────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final UserRole role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    if (role == UserRole.pilgrim || role == UserRole.guest) return const SizedBox.shrink();
    final (color, bg) = switch (role) {
      UserRole.admin => (AppTheme.maroon, AppTheme.maroon.withValues(alpha: 0.1)),
      UserRole.local => (Colors.amber[800]!, Colors.amber.withValues(alpha: 0.12)),
      _ => (Colors.grey, Colors.grey.withValues(alpha: 0.1)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(role.label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Contribute tab ────────────────────────────────────────────────────────

class _ContributeTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ContributeTab> createState() => _ContributeTabState();
}

class _ContributeTabState extends ConsumerState<_ContributeTab> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String? _selectedTempleId;
  String? _selectedTempleName;
  String _category = 'Temple Visit';
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedTempleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a temple')),
      );
      return;
    }
    setState(() => _submitting = true);
    await ref.read(communityFeedProvider.notifier).submitPost(
          title: _titleCtrl.text.trim(),
          body: _bodyCtrl.text.trim(),
          category: _category,
          templeId: _selectedTempleId!,
          templeName: _selectedTempleName!,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    _titleCtrl.clear();
    _bodyCtrl.clear();
    setState(() { _selectedTempleId = null; _selectedTempleName = null; });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Story submitted!'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final isGuest = currentUser == null || currentUser.role == UserRole.guest;
    final temples = ref.watch(allTemplesDbProvider).valueOrNull ?? [];

    if (isGuest) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Set your name to post',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Create a profile to share your temple stories with the community.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
              ),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Create Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.maroon,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ]),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Share Your Temple Story',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          const SizedBox(height: 4),
          Text('Posting as ${currentUser.displayName}',
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 20),

          // Temple picker
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Select Temple',
              prefixIcon: Icon(Icons.temple_hindu),
              border: OutlineInputBorder(),
            ),
            value: _selectedTempleId,
            items: temples.map((t) => DropdownMenuItem(
              value: t.id,
              child: Text(t.name, overflow: TextOverflow.ellipsis),
            )).toList(),
            onChanged: (id) {
              final t = temples.firstWhere((t) => t.id == id);
              setState(() { _selectedTempleId = id; _selectedTempleName = t.name; });
            },
          ),
          const SizedBox(height: 16),

          // Title
          TextFormField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'Give your story a title',
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v == null || v.trim().length < 3) ? 'Title must be at least 3 characters' : null,
          ),
          const SizedBox(height: 16),

          // Body
          TextFormField(
            controller: _bodyCtrl,
            decoration: const InputDecoration(
              labelText: 'Your Story',
              hintText: 'Share your temple experience...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 6,
            validator: (v) => (v == null || v.trim().length < 10) ? 'Please write at least a sentence' : null,
          ),
          const SizedBox(height: 16),

          // Category
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Category',
              prefixIcon: Icon(Icons.category),
              border: OutlineInputBorder(),
            ),
            value: _category,
            items: ['Temple Visit', 'Festival Experience', 'Spiritual Journey', 'Local Traditions']
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
              label: Text(_submitting ? 'Submitting…' : 'Submit Story'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.saffron,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
