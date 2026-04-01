# Identity, Auth & Community Sync — Design

## Architecture overview

```
┌─────────────────────────────────────────────────────┐
│  Screens                                            │
│  CommunityScreen  ProfileScreen  OnboardingScreen   │
└────────────────────┬────────────────────────────────┘
                     │ ref.watch(...)
┌────────────────────▼────────────────────────────────┐
│  Riverpod Providers                                 │
│  currentUserProvider   communityFeedProvider        │
│  userProfileProvider   communityNotifier            │
└────────────────────┬────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────┐
│  Repositories (no raw SQL in screens)               │
│  UserProfileRepository   CommunityRepository (v2)  │
└────────────────────┬────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────┐
│  AppDatabase (SQLite, schema v2)                    │
│  user_profiles   community_stories (extended)       │
└─────────────────────────────────────────────────────┘
```

---

## SQLite schema changes (schema v2)

### New table: `user_profiles`

```sql
CREATE TABLE user_profiles (
  id           TEXT    PRIMARY KEY,          -- UUID
  display_name TEXT    NOT NULL,
  avatar_seed  INTEGER NOT NULL DEFAULT 0,   -- 0–9, drives color/icon
  role         TEXT    NOT NULL DEFAULT 'guest',  -- guest|pilgrim|local|admin
  is_demo      INTEGER NOT NULL DEFAULT 0,   -- 1 for seeded actors
  created_at   TEXT    NOT NULL DEFAULT (datetime('now')),
  updated_at   TEXT    NOT NULL DEFAULT (datetime('now'))
);
```

### Modified table: `community_stories`

Add columns via `ALTER TABLE` in `onUpgrade` (schema v1 → v2):

```sql
ALTER TABLE community_stories ADD COLUMN author_id   TEXT;
ALTER TABLE community_stories ADD COLUMN author_role TEXT NOT NULL DEFAULT 'pilgrim';
ALTER TABLE community_stories ADD COLUMN is_pinned   INTEGER NOT NULL DEFAULT 0;
ALTER TABLE community_stories ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'local';
```

Index for feed query:
```sql
CREATE INDEX idx_stories_feed ON community_stories(is_pinned DESC, created_at DESC);
```

### `app_settings` additions

No schema change needed. New keys:
- `current_user_id` — UUID of the active profile
- `profile_setup_done` — `'1'` once the user has completed or skipped profile setup

---

## Data model: `UserProfile`

```dart
class UserProfile {
  final String id;           // UUID
  final String displayName;
  final int avatarSeed;      // 0–9
  final UserRole role;
  final bool isDemo;
  final DateTime createdAt;
}

enum UserRole { guest, pilgrim, local, admin }
```

Avatar rendering: `avatarSeed % colors.length` picks a background color from a fixed palette. No image uploads needed.

---

## Riverpod providers

### `currentUserProvider`

```dart
// AsyncNotifier — loads from SQLite, exposes current UserProfile
final currentUserProvider = AsyncNotifierProvider<CurrentUserNotifier, UserProfile>(...)
```

Methods:
- `setProfile(displayName, role)` — upserts profile, sets `current_user_id` in settings
- `resetToGuest()` — clears `current_user_id`

### `communityFeedProvider`

```dart
// AsyncNotifier — loads stories joined with author role/name
final communityFeedProvider = AsyncNotifierProvider<CommunityFeedNotifier, List<CommunityPost>>(...)
```

`CommunityPost` is a read model that flattens story + author fields for the UI:

```dart
class CommunityPost {
  final int id;
  final String title;
  final String body;
  final String category;
  final String status;
  final String authorName;
  final UserRole authorRole;
  final String templeId;
  final String templeName;
  final bool isPinned;
  final bool likedByMe;
  final int likeCount;
  final DateTime createdAt;
  final String syncStatus;
}
```

Methods on notifier:
- `submitPost(title, body, category, templeId)` — inserts with current user's id
- `toggleLike(postId)` — updates like state
- `deletePost(postId)` — checks ownership or admin role before deleting
- `refresh()` — reloads from SQLite

---

## Demo actors (seed data)

6 demo profiles seeded at v2:

| id | display_name | role | avatar_seed |
|----|-------------|------|-------------|
| demo_admin_01 | Swami Raghavendra | admin | 0 |
| demo_local_01 | Lakshmi Devi | local | 3 |
| demo_local_02 | Venkat Rao | local | 7 |
| demo_pilgrim_01 | Priya Sharma | pilgrim | 2 |
| demo_pilgrim_02 | Amit Patel | pilgrim | 5 |
| demo_pilgrim_03 | Sneha Reddy | pilgrim | 8 |

8 demo posts seeded at v2, covering Chilkur Balaji, Srisailam, Birla Mandir, Jagannath. One pinned admin post, one pinned local post.

---

## Profile setup flow

```
OnboardingScreen
      │
      ▼ (first launch, after "Get Started")
ProfileSetupScreen
  ├── TextField: display name
  ├── Role picker: Pilgrim / Local
  ├── Avatar preview (color dot based on seed)
  ├── "Save & Continue" → sets profile, navigates to HomeScreen
  └── "Skip for now" → stays as guest, navigates to HomeScreen
```

Profile setup is shown once. After that, accessible via Profile tab → Edit Profile.

---

## Community screen changes

Feed tab:
- Replace `_feedStories` const list with `ref.watch(communityFeedProvider)`
- Show `AsyncValue` loading/error states
- Render role badge next to author name
- Pinned posts get a pin icon and appear first

Contribute tab:
- If `currentUser.role == UserRole.guest` → show "Set your name to post" banner with a button to open ProfileSetupScreen
- Otherwise show the existing form, wired to `communityFeedProvider.submitPost`

---

## Migration order

1. Schema v2 migration in `AppDatabase._onUpgrade`
2. `UserProfile` model + `UserProfileRepository`
3. `currentUserProvider` + `CurrentUserNotifier`
4. Seed demo actors + demo posts in `DatabaseSeeder` (seed v2)
5. `ProfileSetupScreen`
6. Update `OnboardingScreen` to route to `ProfileSetupScreen` on first launch
7. `CommunityPost` read model + `CommunityFeedNotifier`
8. Wire `CommunityScreen` to providers
9. Profile tab / edit profile

---

## Backend sync strategy (future, not MVP)

When ready:
1. Add Supabase project, enable anonymous auth
2. On sign-in, assign `supabase_user_id` to the local profile
3. Background sync worker: query `sync_status = 'pending_upload'`, POST to Supabase, mark `synced`
4. On app start with connectivity, pull new posts from Supabase, insert with `sync_status = 'synced'`
5. Conflict rule: local `liked` state wins; server `like_count` is advisory

No changes to screens needed — they always read from SQLite.

---

## Edge cases

- User deletes app and reinstalls → new UUID, guest state, demo posts re-seeded
- User skips profile setup → can still read feed, cannot post
- Demo posts must not be deletable by non-admin users
- `author_id` may be NULL for legacy rows inserted before v2 — treat as `pilgrim` with name "Anonymous"
- Like toggle must be idempotent (double-tap should not double-count)
- Feed must not crash if `user_profiles` row is missing for an `author_id` (LEFT JOIN, fallback to "Unknown")
