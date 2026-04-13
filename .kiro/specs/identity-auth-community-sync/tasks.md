# Identity, Auth & Community Sync — Tasks

Status key: ✅ Done | ⚠️ Done with gap fixed | 🔲 Future scope

---

## Task 1 — Schema v2 migration ✅
**File:** `lib/database/app_database.dart`

- ✅ `_schemaVersion` bumped to `2`
- ✅ `user_profiles` table in `_createAllTables` (fresh installs)
- ✅ `_onUpgrade` handles v1→v2: `ALTER TABLE community_stories ADD COLUMN` for `author_id`, `author_role`, `is_pinned`, `sync_status`
- ✅ `idx_stories_feed` index added
- ✅ All new columns have safe defaults — no data loss on upgrade

---

## Task 2 — `UserProfile` model + `UserProfileRepository` ✅
**Files:** `lib/models/user_profile.dart`, `lib/database/repositories/user_profile_repository.dart`

- ✅ `UserProfile` model: id, displayName, avatarSeed, role, isDemo, createdAt
- ✅ `UserRole` enum: guest, pilgrim, local, admin with `canPost`, `canPin`, `canDeleteAny`
- ✅ Repository: `getById`, `upsert`, `getAll`, `getDemoActors`
- ✅ `SettingsRepository`: `getCurrentUserId`, `setCurrentUserId`, `clearCurrentUserId`, `profileSetupDone`, `setProfileSetupDone`

---

## Task 3 — `currentUserProvider` ✅
**File:** `lib/database/db_providers.dart`

- ✅ `CurrentUserNotifier extends AsyncNotifier<UserProfile>`
- ✅ `build()`: reads `current_user_id` → loads profile → auto-creates guest on cold start
- ✅ `setProfile(name, role)`: upserts, sets `profile_setup_done`, updates state
- ✅ `resetToGuest()`: clears `current_user_id`, invalidates self

---

## Task 4 — Seed demo actors + demo posts (seed v2) ✅
**File:** `lib/database/database_seeder.dart`

- ✅ `_seedVersion2 = 2` constant
- ✅ `seedIfNeeded` checks both v1 and v2 independently
- ✅ 6 demo `user_profiles`: Swami Raghavendra (admin), Lakshmi Devi (local), Venkat Rao (local), Priya Sharma (pilgrim), Amit Patel (pilgrim), Sneha Reddy (pilgrim)
- ✅ 8 demo `community_stories` across 6 temples, 2 pinned (admin + local)
- ✅ All demo posts: `sync_status = 'local'`, `status = 'published'`, `is_demo` resolved via LEFT JOIN

---

## Task 5 — `ProfileSetupScreen` ✅
**File:** `lib/screens/profile_setup_screen.dart`

- ✅ `TextField` for display name (min 2, max 30 chars, validated)
- ✅ Animated avatar preview (initial letter + deterministic color from name)
- ✅ Role picker: Pilgrim / Local (card-style, not SegmentedButton — clearer on small screens)
- ✅ "Save & Continue" → `currentUserProvider.notifier.setProfile` → `HomeScreen`
- ✅ "Skip for now" → sets `profile_setup_done`, stays guest → `HomeScreen`
- ✅ `isEditing: true` mode for edit-from-profile, pre-fills existing values

---

## Task 6 — Wire `OnboardingScreen` to `ProfileSetupScreen` ✅
**File:** `lib/screens/onboarding_screen.dart`

- ✅ After `setHasOnboarded(true)`, checks `profileSetupDone`
- ✅ If false → pushes `ProfileSetupScreen`
- ✅ If true → pushes `HomeScreen`
- ✅ `ProfileSetupScreen` sets `profile_setup_done = true` on both save and skip

---

## Task 7 — `CommunityPost` read model + `CommunityFeedNotifier` ✅
**Files:** `lib/models/community_post.dart`, `lib/database/repositories/community_repository.dart`, `lib/database/db_providers.dart`

- ✅ `CommunityPost` flat read model with all author fields
- ✅ `CommunityRepository.getFeed()`: LEFT JOIN with `user_profiles`, ORDER BY `is_pinned DESC, created_at DESC`
- ✅ `CommunityRepository.submitPost(...)`: inserts with `sync_status = 'local'`
- ✅ `CommunityFeedNotifier`: `submitPost`, `toggleLike` (optimistic), `deletePost`, `refresh`
- ✅ `deletePost` checks ownership OR admin role
- ✅ `deletePost` additionally blocks deletion of demo posts by non-admins

---

## Task 8 — Wire `CommunityScreen` to providers ✅
**File:** `lib/screens/community_screen.dart`

- ✅ Converted to `ConsumerStatefulWidget`
- ✅ Feed tab: `ref.watch(communityFeedProvider)` with loading/error/empty states
- ✅ Role badges: amber "Local", maroon "Admin", none for pilgrim/guest
- ✅ Pin icon + highlighted border for pinned posts
- ✅ Avatar initials with deterministic color from `authorAvatarSeed`
- ✅ Relative timestamps (Today / Yesterday / Xd ago)
- ✅ Pull-to-refresh
- ✅ Contribute tab: guest gate with "Create Profile" CTA
- ✅ Submit form wired to `communityFeedProvider.notifier.submitPost`
- ✅ `_feedStories` const list removed entirely

---

## Task 9 — Profile tab / edit profile ✅
**Files:** `lib/screens/profile_screen.dart`, `lib/screens/home_screen.dart`

- ✅ Bottom nav index 3 → `ProfileScreen` (was ChatbotScreen placeholder)
- ✅ `ProfileScreen`: avatar, display name, role pill with icon, member since
- ✅ Guest users see "Create Profile" prompt
- ✅ Named users get "Edit Profile" button → `ProfileSetupScreen(isEditing: true)`
- ✅ "Reset identity" with confirmation dialog → `currentUserProvider.notifier.resetToGuest()`

---

## Task 10 — Tests ✅
**File:** `test/database/identity_test.dart`

- ✅ `UserProfileRepository` round-trip (upsert, getById, update, getAll)
- ✅ `getDemoActors` returns only `is_demo = 1` profiles
- ✅ `SettingsRepository` identity keys (getCurrentUserId, clearCurrentUserId, profileSetupDone)
- ✅ Cold-start identity logic: no `current_user_id` → guest auto-created
- ✅ `setProfile` logic: updates name/role, persists to SQLite
- ✅ `resetToGuest` clears `current_user_id`
- ✅ `CommunityRepository.getFeed()` returns pinned posts first
- ✅ Author name resolved from LEFT JOIN (not "Anonymous")
- ✅ Author role correctly mapped for all three roles
- ✅ `submitPost` adds post to feed with correct author join
- ✅ `toggleLike` increments/decrements, floor at 0
- ✅ `delete` removes post from feed
- ✅ Demo seed v2: 6 demo profiles, all 3 roles, 8 posts, ≥2 pinned
- ✅ Demo post `isDemo` flag correctly set/unset

---

## MVP vs future scope

### MVP — COMPLETE ✅
All 10 tasks implemented and tested.

### Future scope 🔲
- Supabase anonymous auth → `signed_in` state
- Background sync worker: `pending_upload` → POST to Supabase → mark `synced`
- Pull remote posts on app start with connectivity
- Phone/Google sign-in
- Comment threads
- Photo uploads on posts
