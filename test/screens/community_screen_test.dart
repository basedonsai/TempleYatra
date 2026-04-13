// Preservation Test — Bug 2: "All Temples" shows all posts
//
// Task 2.2 — Validates: Requirements 2.2.3, 3.2.1, 3.2.2
//
// OBSERVATION (unfixed code):
//   _FeedTab is currently a ConsumerWidget with NO filter state.
//   It watches communityFeedProvider and renders ALL posts unconditionally.
//   There is no _selectedTempleId field — the "All Temples" behavior is the
//   ONLY behavior in the unfixed code.
//
// THIS TEST MUST PASS ON UNFIXED CODE — it confirms the baseline to preserve.
//
// What we verify:
//   When communityFeedProvider returns posts from multiple distinct temples,
//   ALL posts are displayed in the feed (no filtering applied).
//
// After the Bug 2 fix (_FeedTab gains a filter dropdown), this test must
// CONTINUE TO PASS because "All Temples" (null filter) must show all posts.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yatra_app/database/db_providers.dart';
import 'package:yatra_app/models/community_post.dart';
import 'package:yatra_app/models/user_profile.dart';
import 'package:yatra_app/screens/community_screen.dart';

// ---------------------------------------------------------------------------
// Test fixtures — posts from multiple distinct temples
// ---------------------------------------------------------------------------

CommunityPost _makePost({
  required int id,
  required String templeId,
  required String templeName,
  required String title,
}) =>
    CommunityPost(
      id: id,
      title: title,
      body: 'Test body for post $id',
      category: 'Temple Visit',
      status: 'published',
      authorId: 'user_$id',
      authorName: 'Author $id',
      authorRole: UserRole.pilgrim,
      authorAvatarSeed: id % 10,
      templeId: templeId,
      templeName: templeName,
      isPinned: false,
      likedByMe: false,
      likeCount: 0,
      createdAt: DateTime(2024, 1, id),
      syncStatus: 'synced',
      isDemo: false,
    );

/// Three posts from two distinct temples — simulates a real multi-temple feed.
final List<CommunityPost> _multiTemplePosts = [
  _makePost(
    id: 1,
    templeId: 'birla_mandir_hyderabad',
    templeName: 'Birla Mandir, Hyderabad',
    title: 'Birla Mandir Post 1',
  ),
  _makePost(
    id: 2,
    templeId: 'birla_mandir_hyderabad',
    templeName: 'Birla Mandir, Hyderabad',
    title: 'Birla Mandir Post 2',
  ),
  _makePost(
    id: 3,
    templeId: 'chilkur_balaji',
    templeName: 'Chilkur Balaji Temple',
    title: 'Chilkur Balaji Post 1',
  ),
];

// ---------------------------------------------------------------------------
// Helper: pump CommunityScreen with overridden communityFeedProvider
// ---------------------------------------------------------------------------

/// Pumps [CommunityScreen] inside a [ProviderScope] that overrides
/// [communityFeedProvider] with [posts] as resolved data.
///
/// Returns after the first frame so the feed tab is visible.
Future<void> _pumpCommunityScreen(
  WidgetTester tester,
  List<CommunityPost> posts,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        communityFeedProvider.overrideWith(() => _FakeCommunityFeedNotifier(posts)),
      ],
      child: const MaterialApp(home: CommunityScreen()),
    ),
  );
  // Pump once to let the async notifier resolve synchronously.
  await tester.pump();
}

/// A fake [CommunityFeedNotifier] that immediately resolves with [posts].
class _FakeCommunityFeedNotifier extends CommunityFeedNotifier {
  _FakeCommunityFeedNotifier(this._posts);
  final List<CommunityPost> _posts;

  @override
  Future<List<CommunityPost>> build() async => _posts;
}

// ---------------------------------------------------------------------------
// Preservation tests
// ---------------------------------------------------------------------------

void main() {
  group('Preservation P4 — "All Temples" shows all posts (Bug 2 baseline)', () {
    // -----------------------------------------------------------------------
    // P4.1 — All post titles are rendered when no filter is active
    // -----------------------------------------------------------------------
    testWidgets(
      // EXPECTED: PASSES on unfixed code.
      // _FeedTab has no filter state; all posts from communityFeedProvider
      // are rendered unconditionally. After the fix, "All Temples" (null filter)
      // must preserve this behavior.
      'all post titles are visible when communityFeedProvider returns multi-temple posts',
      (WidgetTester tester) async {
        // Arrange & Act: pump with 3 posts from 2 temples
        await _pumpCommunityScreen(tester, _multiTemplePosts);

        // Assert: every post title is rendered in the feed
        for (final post in _multiTemplePosts) {
          expect(
            find.text(post.title),
            findsOneWidget,
            reason: 'PRESERVATION P4.1: Post "${post.title}" (templeId: '
                '${post.templeId}) must be visible when no filter is active. '
                'The "All Temples" default must show all posts.',
          );
        }
      },
    );

    // -----------------------------------------------------------------------
    // P4.2 — Post count equals the full feed length
    // -----------------------------------------------------------------------
    testWidgets(
      // EXPECTED: PASSES on unfixed code.
      // The ListView renders exactly as many _PostCard widgets as there are
      // posts in the feed — no filtering reduces the count.
      'displayed post count equals full feed length when no filter is active',
      (WidgetTester tester) async {
        // Arrange & Act
        await _pumpCommunityScreen(tester, _multiTemplePosts);

        // Assert: the number of Card widgets matches the post count.
        // Each _PostCard renders exactly one Card.
        expect(
          find.byType(Card),
          findsNWidgets(_multiTemplePosts.length),
          reason: 'PRESERVATION P4.2: The feed must display exactly '
              '${_multiTemplePosts.length} cards (one per post) when no '
              'temple filter is active. No posts should be hidden.',
        );
      },
    );

    // -----------------------------------------------------------------------
    // P4.3 — Posts from different temples are all present
    // -----------------------------------------------------------------------
    testWidgets(
      // EXPECTED: PASSES on unfixed code.
      // Posts from both 'birla_mandir_hyderabad' and 'chilkur_balaji' are
      // rendered — the feed is not accidentally pre-filtered to one temple.
      'posts from multiple distinct temples are all visible',
      (WidgetTester tester) async {
        // Arrange & Act
        await _pumpCommunityScreen(tester, _multiTemplePosts);

        // Assert: posts from both temples are visible
        expect(
          find.text('Birla Mandir Post 1'),
          findsOneWidget,
          reason: 'PRESERVATION P4.3: Post from birla_mandir_hyderabad must be visible.',
        );
        expect(
          find.text('Birla Mandir Post 2'),
          findsOneWidget,
          reason: 'PRESERVATION P4.3: Second post from birla_mandir_hyderabad must be visible.',
        );
        expect(
          find.text('Chilkur Balaji Post 1'),
          findsOneWidget,
          reason: 'PRESERVATION P4.3: Post from chilkur_balaji must be visible '
              'alongside Birla Mandir posts — no implicit temple filter applied.',
        );
      },
    );

    // -----------------------------------------------------------------------
    // P4.4 — Empty feed shows "no stories" message (edge case preserved)
    // -----------------------------------------------------------------------
    testWidgets(
      // EXPECTED: PASSES on unfixed code.
      // When communityFeedProvider returns an empty list, the "no stories"
      // placeholder is shown. This edge case must be preserved after the fix.
      'empty feed shows placeholder message',
      (WidgetTester tester) async {
        // Arrange & Act: pump with empty post list
        await _pumpCommunityScreen(tester, []);

        // Assert: placeholder text is shown
        expect(
          find.text('No stories yet. Be the first to share!'),
          findsOneWidget,
          reason: 'PRESERVATION P4.4: Empty feed must show the placeholder '
              'message. This edge case must be preserved after the Bug 2 fix.',
        );
      },
    );
  });
}
