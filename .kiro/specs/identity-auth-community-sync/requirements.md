# Identity, Authentication & Community Sync — Requirements

## Context

Temple Yatra already has:
- SQLite as local source of truth (schema v1)
- Community screen with hardcoded demo stories and local like state
- Onboarding screen that persists `has_onboarded` to SQLite
- `CommunityRepository` with insert/toggleLike/delete
- `community_stories` table with author as a plain string

What is missing:
- Any concept of "who is the current user"
- Role-based display in the community feed (pilgrim / local / admin)
- Demo actors that make the feed feel populated by real people
- Persistence of the current user's identity across restarts
- A path to sync community posts without a heavy backend

---

## Requirements

### REQ-1 — Identity model

**REQ-1.1** The app must support three identity states:
- `guest` — no name chosen, no persistent identity, read-only community access
- `named_guest` — user has chosen a display name and role, stored locally, no account
- `signed_in` — future state, reserved for backend auth (out of MVP scope)

**REQ-1.2** A user profile must have:
- `id` — UUID generated on first launch, persisted in SQLite
- `display_name` — chosen by user or auto-generated (e.g. "Pilgrim #4821")
- `avatar_seed` — integer 0–9, used to pick a deterministic avatar color/icon
- `role` — one of: `guest`, `pilgrim`, `local`, `admin`
- `is_demo` — boolean, true for seeded demo actors only
- `created_at`

**REQ-1.3** The current user's profile must be readable from any screen via a Riverpod provider without touching SQLite directly.

**REQ-1.4** Guest users may browse all content. They may not post to the community feed until they choose a display name (become `named_guest`).

**REQ-1.5** The identity state must survive app restarts. A guest who chose a name must still have that name on next launch.

---

### REQ-2 — Role behaviour in the community feed

**REQ-2.1** Each community post must display the author's role badge:
- `pilgrim` — no badge (default)
- `local` — amber "Local" badge
- `admin` — maroon "Admin" badge

**REQ-2.2** Posts from `admin` or `local` role users may be pinned. Pinned posts appear at the top of the feed regardless of date.

**REQ-2.3** The current user may only delete their own posts. Admin users may delete any post.

**REQ-2.4** The Contribute tab must be disabled (with a prompt to set a name) when the current user is `guest`.

---

### REQ-3 — Demo actors

**REQ-3.1** The seeder must insert 4–6 demo user profiles with distinct roles and realistic names.

**REQ-3.2** The seeder must insert 6–8 demo community posts attributed to those demo users, covering at least 3 different temples and 2 different roles.

**REQ-3.3** At least one demo post must be pinned and from an `admin` or `local` actor.

**REQ-3.4** Demo actors must be clearly marked `is_demo = 1` in the database so they can be filtered or reset independently.

**REQ-3.5** Demo data must be idempotent — re-seeding must not duplicate posts.

---

### REQ-4 — Profile setup flow

**REQ-4.1** On first launch (after onboarding), the app must prompt the user to choose a display name and role (pilgrim or local). Admin is not self-assignable.

**REQ-4.2** The profile setup screen must be skippable. Skipping sets the user to `guest` state.

**REQ-4.3** The user must be able to edit their display name and avatar from a profile screen accessible from the bottom nav.

**REQ-4.4** Profile changes must be persisted immediately to SQLite.

---

### REQ-5 — Community screen wired to SQLite

**REQ-5.1** The community feed must read from `community_stories` joined with `user_profiles` via `author_id`, not from the hardcoded `_feedStories` list.

**REQ-5.2** Submitting a story must insert a row into `community_stories` with the current user's `id` as `author_id`.

**REQ-5.3** Like state must persist across app restarts (already in SQLite, just needs wiring).

**REQ-5.4** The feed must show pinned posts first, then remaining posts sorted by `created_at DESC`.

---

### REQ-6 — Backend sync (minimal, deferred)

**REQ-6.1** Community posts must have a `sync_status` column: `local`, `pending_upload`, `synced`.

**REQ-6.2** When a backend is available (future), posts with `sync_status = 'pending_upload'` must be uploaded and marked `synced`.

**REQ-6.3** The app must work fully offline. Sync is additive, never blocking.

**REQ-6.4** Itineraries and offline audio packs remain local-only. No sync planned.

**REQ-6.5** Backend choice: Supabase (Postgres + REST + anonymous auth) is recommended for its free tier and Flutter SDK. Firebase is acceptable. No custom server needed.

---

## Out of scope for MVP

- Phone/Google sign-in
- Push notifications
- Comment threads
- Photo uploads
- Cross-device itinerary sync
- Admin moderation dashboard
