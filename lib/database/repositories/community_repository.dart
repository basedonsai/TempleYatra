library;

import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../../models/community_post.dart';
import '../../models/user_profile.dart';

class CommunityRepository {
  const CommunityRepository();

  Future<Database> get _db => AppDatabase.instance.db;

  // ── Feed ──────────────────────────────────────────────────────────────────

  /// Returns all posts joined with author profile, pinned first then newest.
  Future<List<CommunityPost>> getFeed() async {
    final rows = await (await _db).rawQuery('''
      SELECT
        cs.id,
        cs.title,
        cs.body,
        cs.category,
        cs.status,
        cs.temple_id,
        cs.temple_name,
        cs.is_pinned,
        cs.liked,
        cs.like_count,
        cs.created_at,
        cs.sync_status,
        COALESCE(cs.author_id, '')          AS author_id,
        COALESCE(cs.author_role, 'pilgrim') AS author_role,
        COALESCE(up.display_name, cs.author, 'Anonymous') AS author_name,
        COALESCE(up.avatar_seed, 0)         AS author_avatar_seed,
        COALESCE(up.is_demo, 0)             AS is_demo
      FROM community_stories cs
      LEFT JOIN user_profiles up ON cs.author_id = up.id
      ORDER BY cs.is_pinned DESC, cs.created_at DESC
    ''');
    return rows.map(_postFromRow).toList();
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  Future<int> submitPost({
    required String title,
    required String body,
    required String category,
    required String templeId,
    required String templeName,
    required String authorId,
    required UserRole authorRole,
  }) async {
    return (await _db).insert('community_stories', {
      'title': title,
      'body': body,
      'category': category,
      'temple_id': templeId,
      'temple_name': templeName,
      'author_id': authorId,
      'author_role': authorRole.name,
      'author': authorId, // legacy column kept for compat
      'status': 'pending',
      'is_pinned': 0,
      'sync_status': 'local',
      'created_at': DateTime.now().toIso8601String(),
      'like_count': 0,
      'liked': 0,
    });
  }

  Future<void> toggleLike(int id, bool currentlyLiked) async {
    await (await _db).rawUpdate('''
      UPDATE community_stories
      SET liked = ?, like_count = MAX(0, like_count + ?)
      WHERE id = ?
    ''', [currentlyLiked ? 0 : 1, currentlyLiked ? -1 : 1, id]);
  }

  /// Deletes a post. Caller must verify ownership or admin role before calling.
  Future<void> delete(int id) async {
    await (await _db).delete(
      'community_stories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Mapping ───────────────────────────────────────────────────────────────

  static CommunityPost _postFromRow(Map<String, dynamic> r) => CommunityPost(
        id: r['id'] as int,
        title: r['title'] as String,
        body: r['body'] as String,
        category: r['category'] as String? ?? 'Temple Visit',
        status: r['status'] as String? ?? 'pending',
        authorId: r['author_id'] as String? ?? '',
        authorName: r['author_name'] as String? ?? 'Anonymous',
        authorRole: UserProfile.roleFromString(
            r['author_role'] as String? ?? 'pilgrim'),
        authorAvatarSeed: r['author_avatar_seed'] as int? ?? 0,
        templeId: r['temple_id'] as String,
        templeName: r['temple_name'] as String? ?? '',
        isPinned: (r['is_pinned'] as int? ?? 0) == 1,
        likedByMe: (r['liked'] as int? ?? 0) == 1,
        likeCount: r['like_count'] as int? ?? 0,
        createdAt: DateTime.parse(r['created_at'] as String),
        syncStatus: r['sync_status'] as String? ?? 'local',
        isDemo: (r['is_demo'] as int? ?? 0) == 1,
      );
}
