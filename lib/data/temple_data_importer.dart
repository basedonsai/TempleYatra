/// TempleDataImporter — reads bundled JSON assets and produces normalized
/// Temple objects. No network calls; all data comes from rootBundle.
library;

import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/temple_model.dart';

class TempleDataImporter {
  const TempleDataImporter._();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Loads both JSON assets and returns a deduplicated, normalized Temple list.
  ///
  /// Existing temples (matched by canonical id) are merged — existing non-null
  /// fields are never overwritten.
  static Future<List<Temple>> load({
    required List<Temple> existingTemples,
    AssetBundle? bundle,
  }) async {
    final b = bundle ?? rootBundle;

    final List<dynamic> deitiesRaw = jsonDecode(
      await b.loadString('assets/temple_dataset/deities.json'),
    ) as List<dynamic>;

    final List<dynamic> statesRaw = jsonDecode(
      await b.loadString('assets/temple_dataset/states.json'),
    ) as List<dynamic>;

    // Collect all temple entries from both files
    final rawEntries = <Map<String, dynamic>>[];

    for (final group in deitiesRaw) {
      final temples = (group as Map<String, dynamic>)['temples'];
      if (temples is List) {
        for (final t in temples) {
          if (t is Map<String, dynamic>) rawEntries.add(t);
        }
      }
    }

    for (final group in statesRaw) {
      final temples = (group as Map<String, dynamic>)['temples'];
      if (temples is List) {
        for (final t in temples) {
          if (t is Map<String, dynamic>) rawEntries.add(t);
        }
      }
    }

    // Normalize each entry; skip entries with no name
    final normalized = <Temple>[];
    for (final entry in rawEntries) {
      final temple = _normalize(entry);
      if (temple != null) normalized.add(temple);
    }

    // Deduplicate by canonical id — keep entry with more non-null fields
    final byId = <String, Temple>{};
    for (final t in normalized) {
      final existing = byId[t.id];
      if (existing == null) {
        byId[t.id] = t;
      } else {
        byId[t.id] = _nonNullCount(t) > _nonNullCount(existing) ? t : existing;
      }
    }

    // Build existing temple map for merge/preservation
    final existingById = <String, Temple>{
      for (final t in existingTemples) t.id: t,
    };

    // Merge dataset entries into existing temples; append new ones
    final result = <Temple>[];

    // First, add all existing temples (merged with dataset data if available)
    for (final existing in existingTemples) {
      final incoming = byId[existing.id];
      result.add(incoming != null ? merge(existing, incoming) : existing);
    }

    // Then append new temples not in existing set
    for (final entry in byId.entries) {
      if (!existingById.containsKey(entry.key)) {
        result.add(entry.value);
      }
    }

    return result;
  }

  /// Derives a canonical snake_case id from a temple name.
  ///
  /// Rules: lowercase → replace [^a-z0-9]+ with '_' → collapse '_+' →
  /// strip leading/trailing '_'.
  static String deriveId(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  /// Merges dataset entry into existing temple, preserving non-null fields.
  ///
  /// Each field is `existing.field ?? incoming.field`.
  static Temple merge(Temple existing, Temple incoming) {
    return Temple(
      id: existing.id,
      placeId: existing.placeId.isNotEmpty ? existing.placeId : incoming.placeId,
      name: existing.name.isNotEmpty ? existing.name : incoming.name,
      latitude: existing.latitude != 0.0 ? existing.latitude : incoming.latitude,
      longitude: existing.longitude != 0.0 ? existing.longitude : incoming.longitude,
      address: existing.address.isNotEmpty ? existing.address : incoming.address,
      distinctiveFeatures: existing.distinctiveFeatures.isNotEmpty
          ? existing.distinctiveFeatures
          : incoming.distinctiveFeatures,
      festivals: existing.festivals.isNotEmpty ? existing.festivals : incoming.festivals,
      prasadamInfo: existing.prasadamInfo.isNotEmpty ? existing.prasadamInfo : incoming.prasadamInfo,
      darshanTimings: existing.darshanTimings.isNotEmpty
          ? existing.darshanTimings
          : incoming.darshanTimings,
      rating: existing.rating ?? incoming.rating,
      userRatingsTotal: existing.userRatingsTotal ?? incoming.userRatingsTotal,
      photoReference: existing.photoReference ?? incoming.photoReference,
      phoneNumber: existing.phoneNumber ?? incoming.phoneNumber,
      website: existing.website ?? incoming.website,
      openingHours: existing.openingHours ?? incoming.openingHours,
      estimatedVisitDurationMinutes:
          existing.estimatedVisitDurationMinutes ?? incoming.estimatedVisitDurationMinutes,
      sthalaPuranam: existing.sthalaPuranam ?? incoming.sthalaPuranam,
      sthalaPuranamEnglish: existing.sthalaPuranamEnglish ?? incoming.sthalaPuranamEnglish,
      sthalaPuranamHindi: existing.sthalaPuranamHindi ?? incoming.sthalaPuranamHindi,
      sthalaPuranamTamil: existing.sthalaPuranamTamil ?? incoming.sthalaPuranamTamil,
      sthalaPuranamTelugu: existing.sthalaPuranamTelugu ?? incoming.sthalaPuranamTelugu,
      rituals: existing.rituals ?? incoming.rituals,
      ritualsEnglish: existing.ritualsEnglish ?? incoming.ritualsEnglish,
      mantras: existing.mantras ?? incoming.mantras,
      significance: existing.significance ?? incoming.significance,
      bestTimeToVisit: existing.bestTimeToVisit ?? incoming.bestTimeToVisit,
      dressCode: existing.dressCode ?? incoming.dressCode,
      audioGuideUrls: existing.audioGuideUrls ?? incoming.audioGuideUrls,
      primaryLanguage: existing.primaryLanguage ?? incoming.primaryLanguage,
      region: existing.region ?? incoming.region,
      deityInfo: existing.deityInfo ?? incoming.deityInfo,
      templeHistory: existing.templeHistory ?? incoming.templeHistory,
      architectureInfo: existing.architectureInfo ?? incoming.architectureInfo,
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Normalizes a raw JSON entry to a Temple, applying fallbacks.
  /// Returns null if no name can be found.
  static Temple? _normalize(Map<String, dynamic> entry) {
    final name = (entry['name'] ?? entry['temple_name'] ?? '') as String;
    if (name.trim().isEmpty) return null;

    final id = deriveId(name);
    if (id.isEmpty) return null;

    final lat = _toDouble(entry['latitude'] ?? entry['lat']);
    final lng = _toDouble(entry['longitude'] ?? entry['lng']);
    final address = _str(entry['address'] ?? entry['location']);
    final deityInfo = _str(entry['deity'] ?? entry['main_deity']);
    final region = _str(entry['state']);
    final distinctiveFeatures = _str(entry['description'] ?? entry['about']);
    final darshanTimings = _str(entry['timings'] ?? entry['darshan_timings'],
        fallback: '6:00 AM - 8:00 PM');
    final prasadamInfo = _str(entry['prasadam']);
    final festivals = _festivalsStr(entry['festivals']);

    return Temple(
      id: id,
      placeId: '',
      name: name,
      latitude: lat,
      longitude: lng,
      address: address,
      distinctiveFeatures: distinctiveFeatures,
      festivals: festivals,
      prasadamInfo: prasadamInfo,
      darshanTimings: darshanTimings,
      region: region.isNotEmpty ? region : null,
      deityInfo: deityInfo.isNotEmpty ? deityInfo : null,
    );
  }

  static double _toDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static String _str(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value.toString().trim();
  }

  static String _festivalsStr(dynamic value) {
    if (value == null) return '';
    if (value is List) return value.map((e) => e.toString().trim()).join(', ');
    return value.toString().trim();
  }

  /// Counts non-null optional fields for deduplication preference.
  static int _nonNullCount(Temple t) {
    int count = 0;
    if (t.address.isNotEmpty) count++;
    if (t.distinctiveFeatures.isNotEmpty) count++;
    if (t.festivals.isNotEmpty) count++;
    if (t.prasadamInfo.isNotEmpty) count++;
    if (t.rating != null) count++;
    if (t.deityInfo != null) count++;
    if (t.region != null) count++;
    if (t.sthalaPuranamEnglish != null) count++;
    if (t.latitude != 0.0) count++;
    if (t.longitude != 0.0) count++;
    return count;
  }
}
