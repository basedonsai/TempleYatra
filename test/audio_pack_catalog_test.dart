import 'package:flutter_test/flutter_test.dart';
import 'package:yatra_app/data/audio_pack_data.dart';
import 'package:yatra_app/models/audio_pack.dart';

/// Validates: Requirements 1.6, 1.7
void main() {
  group('Pack Catalog structural invariants', () {
    /// P8: Pack Size Consistency
    /// For every pack in allAudioPacks, totalSizeBytes must equal the sum of
    /// fileSizeBytes across all tracks in the pack.
    test('P8: Pack Size Consistency — totalSizeBytes equals sum of track sizes',
        () {
      for (final pack in allAudioPacks) {
        final computedSize =
            pack.tracks.map((t) => t.fileSizeBytes).reduce((a, b) => a + b);
        expect(
          pack.totalSizeBytes,
          equals(computedSize),
          reason:
              'Pack "${pack.packId}" has totalSizeBytes=${pack.totalSizeBytes} '
              'but sum of track fileSizeBytes=$computedSize',
        );
      }
    });

    /// P9: Content Category Completeness
    /// For every pack in allAudioPacks, the tracks list must contain at least
    /// one AudioTrack for each ContentCategory value.
    test(
        'P9: Content Category Completeness — every ContentCategory is represented',
        () {
      for (final pack in allAudioPacks) {
        for (final category in ContentCategory.values) {
          final hasCategory = pack.tracks.any((t) => t.category == category);
          expect(
            hasCategory,
            isTrue,
            reason:
                'Pack "${pack.packId}" is missing a track for category "$category"',
          );
        }
      }
    });
  });
}
