/// Identity + community wiring tests.
///
/// Run with: flutter test test/database/identity_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:yatra_app/database/app_database.dart';
import 'package:yatra_app/database/database_seeder.dart';
import 'package:yatra_app/database/repositories/user_profile_repository.dart';
import 'package:yatra_app/database/repositories/settings_repository.dart';
import 'package:yatra_app/database/repositories/community_repository.dart';
import 'package:yatra_app/models/user_profile.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDatabase.instance.deleteDatabase();
    await AppDatabase.instance.db;
  });

  tearDown(() async {
    await AppDatabase.instance.close();
  });

  // ── UserProfileRepository ─────────────────────────────────────────────────

  group('UserProfileRepository', () {
    test('upsert and getById round-trip', () async {
      final repo = const UserProfileRepository();
      final profile = UserProfile(
        id: 'test-uuid-001',
        displayName: 'Priya Sharma',
        avatarSeed: 2,
        role: UserRole.pilgrim,
        createdAt: DateTime(2026, 1, 1),
      );
      await repo.upsert(profile);
      final loaded = await repo.getById('test-uuid-001');
      expect(loaded, isNotNull);
      expect(loaded!.displayName, 'Priya Sharma');
      expect(loaded.role, UserRole.pilgrim);
      expect(loaded.avatarSeed, 2);
    });

    test('upsert updates existing profile', () async {
      final repo = const UserProfileRepository();
      final original = UserProfile(
        id: 'test-uuid-002',
        displayName: 'Old Name',
        avatarSeed: 0,
        role: UserRole.guest,
        createdAt: DateTime(2026, 1, 1),
      );
      await repo.upsert(original);
      final updated = original.copyWith(displayName: 'New Name', role: UserRole.local);
      await repo.upsert(updated);
      final loaded = await repo.getById('test-uuid-002');
      expect(loaded!.displayName, 'New Name');
      expect(loaded.role, UserRole.local);
    });

    test('getById returns null for unknown id', () async {
      final result = await const UserProfileRepository().getById('nonexistent');
      expect(result, isNull);
    });

    test('getAll returns all inserted profiles', () async {
      final repo = const UserProfileRepository();
      for (int i = 0; i < 3; i++) {
        await repo.upsert(UserProfile(
          id: 'profile-$i',
          displayName: 'User $i',
          avatarSeed: i,
          role: UserRole.pilgrim,
          createdAt: DateTime.now(),
        ));
      }
      final all = await repo.getAll();
      expect(all.length, 3);
    });
  });

  // ── SettingsRepository — identity keys ────────────────────────────────────

  group('SettingsRepository — identity', () {
    test('getCurrentUserId returns null before set', () async {
      final id = await const SettingsRepository().getCurrentUserId();
      expect(id, isNull);
    });

    test('setCurrentUserId persists and is readable', () async {
      final repo = const SettingsRepository();
      await repo.setCurrentUserId('abc-123');
      expect(await repo.getCurrentUserId(), 'abc-123');
    });

    test('clearCurrentUserId removes the value', () async {
      final repo = const SettingsRepository();
      await repo.setCurrentUserId('abc-123');
      await repo.clearCurrentUserId();
      expect(await repo.getCurrentUserId(), isNull);
    });

    test('profileSetupDone defaults to false', () async {
      expect(await const SettingsRepository().profileSetupDone, isFalse);
    });

    test('setProfileSetupDone persists true', () async {
      final repo = const SettingsRepository();
      await repo.setProfileSetupDone(true);
      expect(await repo.profileSetupDone, isTrue);
    });
  });

  // ── CommunityRepository.getFeed ───────────────────────────────────────────

  group('CommunityRepository.getFeed', () {
    setUp(() => DatabaseSeeder.seedIfNeeded());

    test('returns demo posts after seed', () async {
      final posts = await const CommunityRepository().getFeed();
      expect(posts, isNotEmpty);
    });

    test('pinned posts appear first', () async {
      final posts = await const CommunityRepository().getFeed();
      final pinnedIndices = posts
          .asMap()
          .entries
          .where((e) => e.value.isPinned)
          .map((e) => e.key)
          .toList();
      final unpinnedIndices = posts
          .asMap()
          .entries
          .where((e) => !e.value.isPinned)
          .map((e) => e.key)
          .toList();
      if (pinnedIndices.isNotEmpty && unpinnedIndices.isNotEmpty) {
        expect(pinnedIndices.last < unpinnedIndices.first, isTrue,
            reason: 'All pinned posts must come before unpinned posts');
      }
    });

    test('author name is resolved from user_profiles join', () async {
      final posts = await const CommunityRepository().getFeed();
      // Demo posts have author_id pointing to demo_admin_01 etc.
      final adminPost = posts.firstWhere((p) => p.authorRole == UserRole.admin);
      expect(adminPost.authorName, isNot('Anonymous'));
      expect(adminPost.authorName.isNotEmpty, isTrue);
    });

    test('author role is correctly mapped', () async {
      final posts = await const CommunityRepository().getFeed();
      expect(posts.any((p) => p.authorRole == UserRole.admin), isTrue);
      expect(posts.any((p) => p.authorRole == UserRole.local), isTrue);
      expect(posts.any((p) => p.authorRole == UserRole.pilgrim), isTrue);
    });
  });

  // ── CommunityRepository.submitPost ───────────────────────────────────────

  group('CommunityRepository.submitPost', () {
    test('inserts post and appears in getFeed', () async {
      final repo = const CommunityRepository();
      // Insert a user profile first
      await const UserProfileRepository().upsert(UserProfile(
        id: 'user-post-test',
        displayName: 'Test Pilgrim',
        avatarSeed: 1,
        role: UserRole.pilgrim,
        createdAt: DateTime.now(),
      ));

      await repo.submitPost(
        title: 'My Test Story',
        body: 'This is a test body with enough content.',
        category: 'Temple Visit',
        templeId: 'chilkur_balaji',
        templeName: 'Chilkur Balaji Temple',
        authorId: 'user-post-test',
        authorRole: UserRole.pilgrim,
      );

      final posts = await repo.getFeed();
      expect(posts.any((p) => p.title == 'My Test Story'), isTrue);
    });

    test('submitted post has correct author name from join', () async {
      final repo = const CommunityRepository();
      await const UserProfileRepository().upsert(UserProfile(
        id: 'user-join-test',
        displayName: 'Joined Author',
        avatarSeed: 3,
        role: UserRole.local,
        createdAt: DateTime.now(),
      ));
      await repo.submitPost(
        title: 'Join Test',
        body: 'Testing the LEFT JOIN author resolution.',
        category: 'Local Traditions',
        templeId: 'srisailam',
        templeName: 'Srisailam',
        authorId: 'user-join-test',
        authorRole: UserRole.local,
      );
      final posts = await repo.getFeed();
      final post = posts.firstWhere((p) => p.title == 'Join Test');
      expect(post.authorName, 'Joined Author');
      expect(post.authorRole, UserRole.local);
    });
  });

  // ── CommunityRepository.toggleLike ───────────────────────────────────────

  group('CommunityRepository.toggleLike', () {
    test('like increments count and sets liked flag', () async {
      final repo = const CommunityRepository();
      final id = await repo.submitPost(
        title: 'Like Test',
        body: 'Testing like toggle.',
        category: 'Temple Visit',
        templeId: 'birla_mandir_hyderabad',
        templeName: 'Birla Mandir',
        authorId: 'anon',
        authorRole: UserRole.pilgrim,
      );
      await repo.toggleLike(id, false); // like
      final posts = await repo.getFeed();
      final post = posts.firstWhere((p) => p.id == id);
      expect(post.likedByMe, isTrue);
      expect(post.likeCount, 1);
    });

    test('unlike decrements count and clears liked flag', () async {
      final repo = const CommunityRepository();
      final id = await repo.submitPost(
        title: 'Unlike Test',
        body: 'Testing unlike.',
        category: 'Temple Visit',
        templeId: 'birla_mandir_hyderabad',
        templeName: 'Birla Mandir',
        authorId: 'anon',
        authorRole: UserRole.pilgrim,
      );
      await repo.toggleLike(id, false); // like
      await repo.toggleLike(id, true);  // unlike
      final posts = await repo.getFeed();
      final post = posts.firstWhere((p) => p.id == id);
      expect(post.likedByMe, isFalse);
      expect(post.likeCount, 0);
    });

    test('like count never goes below 0', () async {
      final repo = const CommunityRepository();
      final id = await repo.submitPost(
        title: 'Floor Test',
        body: 'Like count floor test.',
        category: 'Temple Visit',
        templeId: 'srisailam',
        templeName: 'Srisailam',
        authorId: 'anon',
        authorRole: UserRole.pilgrim,
      );
      // Unlike when already at 0
      await repo.toggleLike(id, true);
      final posts = await repo.getFeed();
      final post = posts.firstWhere((p) => p.id == id);
      expect(post.likeCount, greaterThanOrEqualTo(0));
    });
  });

  // ── CommunityRepository.delete ────────────────────────────────────────────

  group('CommunityRepository.delete', () {
    test('deleted post no longer appears in feed', () async {
      final repo = const CommunityRepository();
      final id = await repo.submitPost(
        title: 'To Delete',
        body: 'This post will be deleted.',
        category: 'Temple Visit',
        templeId: 'keesaragutta',
        templeName: 'Keesaragutta',
        authorId: 'anon',
        authorRole: UserRole.pilgrim,
      );
      await repo.delete(id);
      final posts = await repo.getFeed();
      expect(posts.any((p) => p.id == id), isFalse);
    });
  });

  // ── Demo seed v2 ──────────────────────────────────────────────────────────

  group('Demo seed v2', () {
    setUp(() => DatabaseSeeder.seedIfNeeded());

    test('seeds 6 demo user profiles', () async {
      final profiles = await const UserProfileRepository().getAll();
      final demoProfiles = profiles.where((p) => p.isDemo).toList();
      expect(demoProfiles.length, 6);
    });

    test('demo profiles include all three roles', () async {
      final profiles = await const UserProfileRepository().getAll();
      final demoProfiles = profiles.where((p) => p.isDemo).toList();
      expect(demoProfiles.any((p) => p.role == UserRole.admin), isTrue);
      expect(demoProfiles.any((p) => p.role == UserRole.local), isTrue);
      expect(demoProfiles.any((p) => p.role == UserRole.pilgrim), isTrue);
    });

    test('seeds 8 demo posts', () async {
      final posts = await const CommunityRepository().getFeed();
      expect(posts.length, 8);
    });

    test('at least 2 posts are pinned', () async {
      final posts = await const CommunityRepository().getFeed();
      expect(posts.where((p) => p.isPinned).length, greaterThanOrEqualTo(2));
    });

    test('getDemoActors returns only demo profiles', () async {
      // Add a non-demo profile to ensure filtering works
      await const UserProfileRepository().upsert(UserProfile(
        id: 'real-user-001',
        displayName: 'Real User',
        avatarSeed: 1,
        role: UserRole.pilgrim,
        createdAt: DateTime.now(),
      ));
      final demoActors = await const UserProfileRepository().getDemoActors();
      expect(demoActors.length, 6);
      expect(demoActors.every((p) => p.isDemo), isTrue);
    });
  });

  // ── Identity logic (repository-level, no widget tree) ────────────────────

  group('Identity logic', () {
    test('cold start: no current_user_id → guest profile auto-created', () async {
      // Simulate what CurrentUserNotifier.build() does
      final settings = const SettingsRepository();
      final profileRepo = const UserProfileRepository();

      final existingId = await settings.getCurrentUserId();
      expect(existingId, isNull); // nothing set yet

      // Auto-create guest
      const id = 'cold-start-uuid';
      final guest = UserProfile(
        id: id,
        displayName: 'Pilgrim #COLD',
        avatarSeed: 3,
        role: UserRole.guest,
        createdAt: DateTime.now(),
      );
      await profileRepo.upsert(guest);
      await settings.setCurrentUserId(id);

      final loaded = await profileRepo.getById(id);
      expect(loaded, isNotNull);
      expect(loaded!.role, UserRole.guest);
      expect(await settings.getCurrentUserId(), id);
    });

    test('setProfile: updates role and name, persists to SQLite', () async {
      // Simulate setProfile(name, role)
      final profileRepo = const UserProfileRepository();
      const id = 'set-profile-uuid';
      final original = UserProfile(
        id: id,
        displayName: 'Pilgrim #XXXX',
        avatarSeed: 5,
        role: UserRole.guest,
        createdAt: DateTime.now(),
      );
      await profileRepo.upsert(original);

      // Simulate the update
      final updated = original.copyWith(displayName: 'Lakshmi Devi', role: UserRole.local);
      await profileRepo.upsert(updated);
      await const SettingsRepository().setProfileSetupDone(true);

      final loaded = await profileRepo.getById(id);
      expect(loaded!.displayName, 'Lakshmi Devi');
      expect(loaded.role, UserRole.local);
      expect(await const SettingsRepository().profileSetupDone, isTrue);
    });

    test('resetToGuest: clears current_user_id', () async {
      final settings = const SettingsRepository();
      await settings.setCurrentUserId('some-uuid');
      await settings.clearCurrentUserId();
      expect(await settings.getCurrentUserId(), isNull);
    });
  });

  // ── Demo post deletion guard ──────────────────────────────────────────────

  group('Demo post deletion guard', () {
    setUp(() => DatabaseSeeder.seedIfNeeded());

    test('demo posts are marked isDemo = true in feed', () async {
      final posts = await const CommunityRepository().getFeed();
      expect(posts.any((p) => p.isDemo), isTrue);
    });

    test('non-demo post is not marked isDemo', () async {
      final repo = const CommunityRepository();
      final id = await repo.submitPost(
        title: 'Non-demo post',
        body: 'This is a regular user post.',
        category: 'Temple Visit',
        templeId: 'chilkur_balaji',
        templeName: 'Chilkur Balaji Temple',
        authorId: 'regular-user',
        authorRole: UserRole.pilgrim,
      );
      final posts = await repo.getFeed();
      final post = posts.firstWhere((p) => p.id == id);
      expect(post.isDemo, isFalse);
    });
  });
}
