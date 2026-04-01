import 'user_profile.dart';

/// Flat read model for the community feed.
/// Joins community_stories + user_profiles — screens never touch raw rows.
class CommunityPost {
  final int id;
  final String title;
  final String body;
  final String category;
  final String status;   // 'pending' | 'published'
  final String authorId;
  final String authorName;
  final UserRole authorRole;
  final int authorAvatarSeed;
  final String templeId;
  final String templeName;
  final bool isPinned;
  final bool likedByMe;
  final int likeCount;
  final DateTime createdAt;
  final String syncStatus; // 'local' | 'pending_upload' | 'synced'
  final bool isDemo;

  const CommunityPost({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.status,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.authorAvatarSeed,
    required this.templeId,
    required this.templeName,
    required this.isPinned,
    required this.likedByMe,
    required this.likeCount,
    required this.createdAt,
    required this.syncStatus,
    this.isDemo = false,
  });

  CommunityPost copyWith({bool? likedByMe, int? likeCount}) => CommunityPost(
        id: id,
        title: title,
        body: body,
        category: category,
        status: status,
        authorId: authorId,
        authorName: authorName,
        authorRole: authorRole,
        authorAvatarSeed: authorAvatarSeed,
        templeId: templeId,
        templeName: templeName,
        isPinned: isPinned,
        likedByMe: likedByMe ?? this.likedByMe,
        likeCount: likeCount ?? this.likeCount,
        createdAt: createdAt,
        syncStatus: syncStatus,
        isDemo: isDemo,
      );
}
