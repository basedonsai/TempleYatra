// Temple data model
class Temple {
  final String id;
  final String name;
  final String placeId;
  final double latitude;
  final double longitude;
  final String address;
  final String distinctiveFeatures;
  final String festivals;
  final String prasadamInfo;
  final String darshanTimings;
  
  // Google Places data (optional - may be null in offline mode)
  final double? rating;
  final int? userRatingsTotal;
  final String? photoReference;
  final String? phoneNumber;
  final String? website;
  final String? openingHours;
  
  // Simulation data
  final int? estimatedVisitDurationMinutes;
  
  // NEW: Cultural content fields for storytelling feature
  final String? sthalaPuranam;        // Temple legend/history in original language
  final String? sthalaPuranamEnglish; // English translation
  final String? sthalaPuranamHindi;   // Hindi translation
  final String? sthalaPuranamTamil;   // Tamil translation
  final String? sthalaPuranamTelugu;  // Telugu translation
  final String? rituals;              // Daily rituals information
  final String? ritualsEnglish;       // English translation
  final String? mantras;             // Important mantras with meanings
  final String? significance;         // Religious/cultural significance
  final String? bestTimeToVisit;     // Recommended timing
  final String? dressCode;           // Dress code requirements
  final List<String>? audioGuideUrls; // Pre-recorded audio URLs
  final String? primaryLanguage;      // Primary language (ta, te, hi, etc.)
  final String? region;               // Region for accent matching
  final String? deityInfo;           // Information about main deity
  final String? templeHistory;       // Historical information
  final String? architectureInfo;    // Architectural details
  
  Temple({
    required this.id,
    required this.name,
    required this.placeId,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.distinctiveFeatures,
    required this.festivals,
    required this.prasadamInfo,
    required this.darshanTimings,
    this.rating,
    this.userRatingsTotal,
    this.photoReference,
    this.phoneNumber,
    this.website,
    this.openingHours,
    this.estimatedVisitDurationMinutes,
    // NEW fields
    this.sthalaPuranam,
    this.sthalaPuranamEnglish,
    this.sthalaPuranamHindi,
    this.sthalaPuranamTamil,
    this.sthalaPuranamTelugu,
    this.rituals,
    this.ritualsEnglish,
    this.mantras,
    this.significance,
    this.bestTimeToVisit,
    this.dressCode,
    this.audioGuideUrls,
    this.primaryLanguage,
    this.region,
    this.deityInfo,
    this.templeHistory,
    this.architectureInfo,
  });

  /// Get sthala puranam in specified language
  String? getSthalaPuranam(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'hi':
        return sthalaPuranamHindi ?? sthalaPuranamEnglish;
      case 'ta':
        return sthalaPuranamTamil ?? sthalaPuranamEnglish;
      case 'te':
        return sthalaPuranamTelugu ?? sthalaPuranamEnglish;
      case 'en':
      default:
        return sthalaPuranamEnglish ?? sthalaPuranam;
    }
  }

  /// Get rituals in specified language
  String? getRituals(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'en':
      default:
        return ritualsEnglish ?? rituals;
    }
  }

  /// Convert to LatLng for Google Maps
  double get lat => latitude;
  double get lng => longitude;

  /// Get formatted rating string
  String get ratingText => rating != null ? '${rating?.toStringAsFixed(1)} ⭐' : 'N/A';

  /// Get formatted review count
  String get reviewsText {
    if (userRatingsTotal == null) return 'No reviews';
    if (userRatingsTotal! >= 1000) {
      return '${(userRatingsTotal! / 1000).toStringAsFixed(1)}k reviews';
    }
    return '$userRatingsTotal reviews';
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'placeId': placeId,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'distinctiveFeatures': distinctiveFeatures,
      'festivals': festivals,
      'prasadamInfo': prasadamInfo,
      'darshanTimings': darshanTimings,
      'rating': rating,
      'userRatingsTotal': userRatingsTotal,
      'photoReference': photoReference,
      'phoneNumber': phoneNumber,
      'website': website,
      'openingHours': openingHours,
      'estimatedVisitDurationMinutes': estimatedVisitDurationMinutes,
      // Cultural content fields
      'sthalaPuranam': sthalaPuranam,
      'sthalaPuranamEnglish': sthalaPuranamEnglish,
      'sthalaPuranamHindi': sthalaPuranamHindi,
      'sthalaPuranamTamil': sthalaPuranamTamil,
      'sthalaPuranamTelugu': sthalaPuranamTelugu,
      'rituals': rituals,
      'ritualsEnglish': ritualsEnglish,
      'mantras': mantras,
      'significance': significance,
      'bestTimeToVisit': bestTimeToVisit,
      'dressCode': dressCode,
      'audioGuideUrls': audioGuideUrls,
      'primaryLanguage': primaryLanguage,
      'region': region,
      'deityInfo': deityInfo,
      'templeHistory': templeHistory,
      'architectureInfo': architectureInfo,
    };
  }

  /// Create Temple from JSON
  factory Temple.fromJson(Map<String, dynamic> json) {
    return Temple(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      placeId: json['placeId'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      address: json['address'] ?? '',
      distinctiveFeatures: json['distinctiveFeatures'] ?? '',
      festivals: json['festivals'] ?? '',
      prasadamInfo: json['prasadamInfo'] ?? '',
      darshanTimings: json['darshanTimings'] ?? '',
      rating: json['rating']?.toDouble(),
      userRatingsTotal: json['userRatingsTotal'],
      photoReference: json['photoReference'],
      phoneNumber: json['phoneNumber'],
      website: json['website'],
      openingHours: json['openingHours'],
      estimatedVisitDurationMinutes: json['estimatedVisitDurationMinutes'],
      // Cultural content fields
      sthalaPuranam: json['sthalaPuranam'],
      sthalaPuranamEnglish: json['sthalaPuranamEnglish'],
      sthalaPuranamHindi: json['sthalaPuranamHindi'],
      sthalaPuranamTamil: json['sthalaPuranamTamil'],
      sthalaPuranamTelugu: json['sthalaPuranamTelugu'],
      rituals: json['rituals'],
      ritualsEnglish: json['ritualsEnglish'],
      mantras: json['mantras'],
      significance: json['significance'],
      bestTimeToVisit: json['bestTimeToVisit'],
      dressCode: json['dressCode'],
      audioGuideUrls: json['audioGuideUrls'] != null 
          ? List<String>.from(json['audioGuideUrls']) 
          : null,
      primaryLanguage: json['primaryLanguage'],
      region: json['region'],
      deityInfo: json['deityInfo'],
      templeHistory: json['templeHistory'],
      architectureInfo: json['architectureInfo'],
    );
  }
}

class TempleReview {
  final String authorName;
  final String text;
  final double rating;
  final String timeAgo;

  TempleReview({
    required this.authorName,
    required this.text,
    required this.rating,
    required this.timeAgo,
  });
}
