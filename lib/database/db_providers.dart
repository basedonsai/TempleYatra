/// Riverpod providers for all database repositories.
///
/// Usage in screens:
///   final temples = ref.watch(allTemplesProvider);
///   final festivals = ref.watch(templeFestivalsDbProvider('chilkur_balaji'));
library;

import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'repositories/temple_repository.dart';
import 'repositories/festival_repository.dart';
import 'repositories/audio_pack_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/community_repository.dart';
import 'repositories/itinerary_draft_repository.dart';
import 'repositories/user_profile_repository.dart';
import '../models/temple_model.dart';
import '../models/festival_event.dart';
import '../models/audio_pack.dart';
import '../models/user_profile.dart';
import '../models/community_post.dart';

// ── Repository singletons ─────────────────────────────────────────────────

final templeRepositoryProvider = Provider((_) => const TempleRepository());
final festivalRepositoryProvider = Provider((_) => const FestivalRepository());
final audioPackRepositoryProvider = Provider((_) => const AudioPackRepository());
final settingsRepositoryProvider = Provider((_) => const SettingsRepository());
final communityRepositoryProvider = Provider((_) => const CommunityRepository());
final itineraryDraftRepositoryProvider = Provider((_) => const ItineraryDraftRepository());
final userProfileRepositoryProvider = Provider((_) => const UserProfileRepository());

// ── Temple providers ──────────────────────────────────────────────────────

/// All temples from SQLite, sorted by name.
final allTemplesDbProvider = FutureProvider<List<Temple>>((ref) {
  return ref.read(templeRepositoryProvider).getAll();
});

/// Single temple by id.
final templeByIdDbProvider = FutureProvider.family<Temple?, String>((ref, id) {
  return ref.read(templeRepositoryProvider).getById(id);
});

/// Temple search results.
final templeSearchDbProvider = FutureProvider.family<List<Temple>, String>((ref, query) {
  if (query.trim().isEmpty) return ref.read(templeRepositoryProvider).getAll();
  return ref.read(templeRepositoryProvider).search(query);
});

// ── Festival providers ────────────────────────────────────────────────────

/// All festivals for a specific temple.
final templeFestivalsDbProvider = FutureProvider.family<List<FestivalEvent>, String>(
  (ref, templeId) => ref.read(festivalRepositoryProvider).getForTemple(templeId),
);

/// Next N upcoming festivals across all temples.
final upcomingFestivalsDbProvider = FutureProvider.family<List<FestivalEvent>, int>(
  (ref, limit) => ref.read(festivalRepositoryProvider).getUpcoming(limit: limit),
);

// ── Audio pack providers ──────────────────────────────────────────────────

/// All audio packs with their tracks.
final allAudioPacksDbProvider = FutureProvider<List<AudioPack>>((ref) {
  return ref.read(audioPackRepositoryProvider).getAll();
});

/// Audio pack for a specific temple.
final audioPackForTempleDbProvider = FutureProvider.family<AudioPack?, String>(
  (ref, templeId) => ref.read(audioPackRepositoryProvider).getForTemple(templeId),
);

// ── Community providers ───────────────────────────────────────────────────
// communityFeedProvider (AsyncNotifier) is defined below — use that instead.

// ── Itinerary draft providers ─────────────────────────────────────────────

final itineraryDraftsDbProvider = FutureProvider<List<ItineraryDraft>>((ref) {
  return ref.read(itineraryDraftRepositoryProvider).getAll();
});

// ── Identity providers ────────────────────────────────────────────────────

/// The current user's profile. Always returns a valid UserProfile —
/// creates a guest profile on first launch if none exists.
final currentUserProvider =
    AsyncNotifierProvider<CurrentUserNotifier, UserProfile>(
  CurrentUserNotifier.new,
);

class CurrentUserNotifier extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() async {
    final settings = ref.read(settingsRepositoryProvider);
    final profileRepo = ref.read(userProfileRepositoryProvider);

    final existingId = await settings.getCurrentUserId();
    if (existingId != null) {
      final profile = await profileRepo.getById(existingId);
      if (profile != null) return profile;
    }

    // Auto-create a guest profile with a random seed
    final id = const Uuid().v4();
    final seed = Random().nextInt(10);
    final guest = UserProfile(
      id: id,
      displayName: 'Pilgrim #${id.substring(0, 4).toUpperCase()}',
      avatarSeed: seed,
      role: UserRole.guest,
      createdAt: DateTime.now(),
    );
    await profileRepo.upsert(guest);
    await settings.setCurrentUserId(id);
    return guest;
  }

  /// Set or update the current user's display name and role.
  Future<void> setProfile(String displayName, UserRole role) async {
    final current = await future;
    final updated = current.copyWith(
      displayName: displayName.trim(),
      role: role,
    );
    await ref.read(userProfileRepositoryProvider).upsert(updated);
    state = AsyncData(updated);
    await ref.read(settingsRepositoryProvider).setProfileSetupDone(true);
  }

  Future<void> resetToGuest() async {
    await ref.read(settingsRepositoryProvider).clearCurrentUserId();
    ref.invalidateSelf();
  }
}

// ── Recently viewed notifier ─────────────────────────────────────────────

class RecentlyViewedNotifier extends StateNotifier<List<String>> {
  RecentlyViewedNotifier() : super([]);

  void viewed(String templeId) {
    final updated = [templeId, ...state.where((id) => id != templeId)];
    state = updated.take(5).toList();
  }
}

final recentlyViewedProvider =
    StateNotifierProvider<RecentlyViewedNotifier, List<String>>(
  (_) => RecentlyViewedNotifier(),
);

// ── Community feed notifier ───────────────────────────────────────────────

final communityFeedProvider =
    AsyncNotifierProvider<CommunityFeedNotifier, List<CommunityPost>>(
  CommunityFeedNotifier.new,
);

class CommunityFeedNotifier extends AsyncNotifier<List<CommunityPost>> {
  @override
  Future<List<CommunityPost>> build() {
    return ref.read(communityRepositoryProvider).getFeed();
  }

  Future<void> submitPost({
    required String title,
    required String body,
    required String category,
    required String templeId,
    required String templeName,
  }) async {
    final user = await ref.read(currentUserProvider.future);
    if (!user.role.canPost) return;

    await ref.read(communityRepositoryProvider).submitPost(
          title: title,
          body: body,
          category: category,
          templeId: templeId,
          templeName: templeName,
          authorId: user.id,
          authorRole: user.role,
        );
    ref.invalidateSelf();
  }

  Future<void> toggleLike(int postId) async {
    final posts = state.valueOrNull ?? [];
    final post = posts.where((p) => p.id == postId).firstOrNull;
    if (post == null) return;

    // Optimistic update
    state = AsyncData(posts.map((p) {
      if (p.id != postId) return p;
      return p.copyWith(
        likedByMe: !p.likedByMe,
        likeCount: p.likeCount + (p.likedByMe ? -1 : 1),
      );
    }).toList());

    await ref.read(communityRepositoryProvider).toggleLike(postId, post.likedByMe);
  }

  Future<void> deletePost(int postId) async {
    final user = await ref.read(currentUserProvider.future);
    final posts = state.valueOrNull ?? [];
    final post = posts.where((p) => p.id == postId).firstOrNull;
    if (post == null) return;

    // Demo posts can only be deleted by admins
    if (post.isDemo && !user.role.canDeleteAny) return;

    final canDelete = post.authorId == user.id || user.role.canDeleteAny;
    if (!canDelete) return;

    await ref.read(communityRepositoryProvider).delete(postId);
    state = AsyncData(posts.where((p) => p.id != postId).toList());
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}
