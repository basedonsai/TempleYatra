# Temple Yatra - Google Maps Platform Implementation Plan

## Updated: Google Maps SDK + APIs Integration

**Objective**: Build a temple directory and navigation application for Hyderabad and Telangana region using Google Maps Platform APIs.

---

## 1. Temple Data (10 Temples - Hyderabad & Telangana)

| # | Temple | Coordinates | Distinctive Features |
|---|--------|-------------|---------------------|
| 1 | Chilkur Balaji Temple | 17.3975°N, 78.2833°E | Famous "Visa Balaji", no priest donations, prasadam distribution |
| 2 | Jagannath Temple, Hyderabad | 17.4236°N, 78.4538°E | Replica of Puri temple, Rath Yatra, Mahaprasadam |
| 3 | Sri Peddamma Thalli Temple | 17.4225°N, 78.4088°E | Bonalu festival, pot offerings, folk performances |
| 4 | Birla Mandir, Hyderabad | 17.4061°N, 78.4686°E | White marble Venkateswara, city views, free darshan |
| 5 | Keesaragutta Temple | 17.6333°N, 77.9833°E | Ancient Shiva temple, hilltop, sunrise views |
| 6 | Akkanna Madanna Temple | 17.3608°N, 78.4742°E | Old City Mahankali temple, Bonalu celebrations |
| 7 | Sanghi Temple | 17.3308°N, 77.6833°E | Venkateswara complex, hilltop, evening light shows |
| 8 | Karmanghat Hanuman Temple | 17.3483°N, 78.5167°E | Panchmukhi Hanuman idol, daily spiritual programs |
| 9 | Ujjaini Mahankali Temple | 17.4394°N, 78.5011°E | Secunderabad Bonalu, decorated bulls, processions |
| 10 | ISKCON Radha Madanmohan | 17.4100°N, 78.4500°E | ISKCON center, Bhagavad Gita classes, kirtans |

---

## 2. Google Maps Platform Integration

### 2.1 Required APIs

| API | Purpose | Free Tier |
|-----|---------|-----------|
| Maps SDK for Android | Interactive map rendering | $200/month credit |
| Places API | Temple details, photos, reviews | 1,000 requests/month free |
| Distance Matrix API | Travel times between temples | 1,000 elements/month free |
| Directions API | Multi-stop routing | 1,000 requests/day free |

### 2.2 Setup Requirements

```bash
# 1. Create Google Cloud Project
# 2. Enable APIs:
#    - Maps SDK for Android
#    - Places API
#    - Directions API
#    - Distance Matrix API

# 3. Get API Key from Google Cloud Console
# 4. Add to android/app/src/main/AndroidManifest.xml
```

### 2.3 API Key Configuration

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<manifest>
    <application>
        <!-- Add this meta-data -->
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
    </application>
</manifest>
```

---

## 3. Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Google Maps
  google_maps_flutter: ^2.5.0
  
  # HTTP requests for APIs
  dio: ^5.4.0
  
  # State management
  riverpod: ^2.4.0
  
  # JSON serialization
  json_annotation: ^4.8.1
  
  # Location services
  geolocator: ^11.0.0
  
  # Image loading
  cached_network_image: ^3.3.0
  
  # URL launcher
  url_launcher: ^6.2.0
  
  # For TTS voice guidance
  flutter_tts: ^3.8.0
  
  # UI utilities
  flutter_animate: ^4.2.0
  google_fonts: ^6.1.0
```

---

## 4. Application Architecture

### 4.1 Core Components

```
┌─────────────────────────────────────────────────────────────┐
│                    TempleYatra App                           │
├─────────────────────────────────────────────────────────────┤
│  Presentation Layer                                          │
│  ├── Home Screen (Temple List)                             │
│  ├── Temple Detail Screen                                  │
│  ├── Map Screen (Interactive Google Maps)                  │
│  └── Route Planning Screen                                 │
├─────────────────────────────────────────────────────────────┤
│  Domain Layer                                               │
│  ├── Temple Model                                          │
│  ├── Route Model                                           │
│  ├── Navigation Step Model                                 │
│  └── Use Cases                                             │
├─────────────────────────────────────────────────────────────┤
│  Data Layer                                                 │
│  ├── Google Places API Service                            │
│  ├── Google Directions API Service                         │
│  ├── Distance Matrix API Service                          │
│  └── Local Cache (Hive)                                   │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 Data Models

```dart
// Temple model from Google Places
class Temple {
  final String placeId;
  final String name;
  final double latitude;
  final double longitude;
  final String formattedAddress;
  final String? photoReference;
  final double rating;
  final int userRatingsTotal;
  final String? openingHours;
  final String? phoneNumber;
  final String? website;
  final List<String> reviews;
  final TempleType type;
  
  // Custom fields (not from Google)
  final String distinctiveFeatures;
  final String festivals;
  final String prasadamInfo;
  final String darshanTimings;
}

// Route model
class RouteResult {
  final List<LatLng> polylinePoints;
  final List<NavigationStep> steps;
  final Duration duration;
  final double distance;
  final String summary;
}

// Navigation step
class NavigationStep {
  final String instruction;
  final double distance;
  final Duration duration;
  final LatLng startLocation;
  final LatLng endLocation;
  final String maneuver; // turn, straight, etc.
}
```

---

## 5. Implementation Plan

### Phase 1: Setup & Temple Directory (Days 1-2)

| Task | Duration | Deliverable |
|------|----------|-------------|
| Google Cloud setup | 1 hour | API key obtained |
| Project dependencies | 2 hours | pubspec.yaml configured |
| Android config | 2 hours | API key in manifest |
| Temple data models | 3 hours | 10 temple models |
| API service layer | 4 hours | Dio client for Google APIs |
| Temple list screen | 4 hours | ListView with temple cards |
| API fallback cache | 2 hours | Local JSON backup |

### Phase 2: Temple Details Integration (Days 3-4)

| Task | Duration | Deliverable |
|------|----------|-------------|
| Place API integration | 3 hours | Fetch temple details |
| Photos integration | 2 hours | Display temple images |
| Reviews display | 2 hours | Show ratings/reviews |
| Opening hours | 1 hour | Display timings |
| Contact info | 1 hour | Phone/website buttons |
| Detail screen UI | 4 hours | Beautiful detail layout |
| Offline caching | 2 hours | Cache API responses |

### Phase 3: Interactive Map (Days 5-6)

| Task | Duration | Deliverable |
|------|----------|-------------|
| Google Maps setup | 2 hours | Map displayed |
| Temple markers | 2 hours | Custom markers on map |
| Info windows | 2 hours | Click-to-view details |
| Current location | 2 hours | Geolocator integration |
| Map clustering | 2 hours | Handle zoom levels |
| Style customization | 2 hours | Custom map style |

### Phase 4: Routing & Navigation (Days 7-8)

| Task | Duration | Deliverable |
|------|----------|-------------|
| Directions API | 3 hours | Get route polylines |
| Multi-stop routing | 4 hours | TSP algorithm |
| Distance matrix | 2 hours | Calculate times/distances |
| Route display | 3 hours | Polylines on map |
| Turn-by-turn | 3 hours | Text instructions |
| Voice guidance | 2 hours | TTS integration |

### Phase 5: Demo Features (Day 9)

| Task | Duration | Deliverable |
|------|----------|-------------|
| Offline demo mode | 2 hours | Cached data fallback |
| Error handling | 2 hours | Graceful API failures |
| Loading states | 1 hour | Shimmer effects |
| Refresh button | 1 hour | Manual data refresh |
| Demo script | 2 hours | Presentation flow |

---

## 6. API Integration Details

### 6.1 Places API Service

```dart
class PlacesApiService {
  final Dio _dio;
  final String _apiKey;
  
  Future<TempleDetails?> getTempleDetails(String placeId) async {
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/details/json',
        queryParameters: {
          'place_id': placeId,
          'fields': 'name,formatted_address,geometry,rating,'
              'user_ratings_total,photos,opening_hours,'
              'formatted_phone_number,website,reviews',
          'key': _apiKey,
        },
      );
      
      if (response.statusCode == 200) {
        return TempleDetails.fromJson(response.data['result']);
      }
    } catch (e) {
      print('Places API Error: $e');
      return null; // Will fallback to cached data
    }
  }
  
  Future<List<String>> getTemplePhotos(String photoReference) async {
    final response = await _dio.get(
      'https://maps.googleapis.com/maps/api/place/photo',
      queryParameters: {
        'photo_reference': photoReference,
        'maxwidth': 400,
        'key': _apiKey,
      },
    );
    return [response.data];
  }
}
```

### 6.2 Directions API Service

```dart
class DirectionsApiService {
  final Dio _dio;
  final String _apiKey;
  
  Future<RouteResult?> getRoute({
    required List<LatLng> waypoints,
    required TravelMode travelMode,
  }) async {
    final origin = '${waypoints.first.latitude},${waypoints.first.longitude}';
    final destination = '${waypoints.last.latitude},${waypoints.last.longitude}';
    final via = waypoints.skip(1).take(waypoints.length - 2)
        .map((p) => '${p.latitude},${p.longitude}')
        .join('|');
    
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: {
          'origin': origin,
          'destination': destination,
          'waypoints': 'optimize:true|$via',
          'mode': travelMode.toString().split('.').last,
          'key': _apiKey,
        },
      );
      
      if (response.statusCode == 200) {
        return RouteResult.fromJson(response.data['routes'][0]);
      }
    } catch (e) {
      print('Directions API Error: $e');
      return null;
    }
  }
}
```

### 6.3 Distance Matrix API Service

```dart
class DistanceMatrixService {
  final Dio _dio;
  final String _apiKey;
  
  Future<List<DistanceResult>> getDistances({
    required List<LatLng> origins,
    required List<LatLng> destinations,
    required TravelMode mode,
  }) async {
    final originsStr = origins.map((o) => '${o.latitude},${o.longitude}').join('|');
    final destsStr = destinations.map((d) => '${d.latitude},${d.longitude}').join('|');
    
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/distancematrix/json',
        queryParameters: {
          'origins': originsStr,
          'destinations': destsStr,
          'mode': mode.toString().split('.').last,
          'key': _apiKey,
        },
      );
      
      return DistanceResult.fromJson(response.data);
    } catch (e) {
      print('Distance Matrix API Error: $e');
      return [];
    }
  }
}
```

---

## 7. UI Screens

### 7.1 Temple List Screen

```
┌─────────────────────────────────────────┐
│  🔍 Search temples...           🔄     │
├─────────────────────────────────────────┤
│  📍 Hyderabad & Telangana              │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ 🏛️ Birla Mandir                 │   │
│  │ ⭐ 4.7 (2,341)  📍 5.2 km      │   │
│  │ White marble temple, city views │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ 🏛️ Chilkur Balaji               │   │
│  │ ⭐ 4.6 (1,892)  📍 18.3 km     │   │
│  │ Visa Balaji, prasadam           │   │
│  └─────────────────────────────────┘   │
│                                         │
│  [View on Map]  [Plan Yatra]           │
└─────────────────────────────────────────┘
```

### 7.2 Temple Detail Screen

```
┌─────────────────────────────────────────┐
│  ←              🔙                        │
├─────────────────────────────────────────┤
│                                         │
│         [Temple Photo Gallery]          │
│                                         │
├─────────────────────────────────────────┤
│  🏛️ Birla Mandir, Hyderabad              │
│  ⭐ 4.7 ⭐ ⭐ ⭐ ⭐ (2,341 reviews)      │
│                                         │
│  📍 Necklace Road, Hyderabad             │
│  📞 040-xxxx-xxxx                       │
│  🌐 birlamandir.org                     │
│                                         │
├─────────────────────────────────────────┤
│  🕐 Today's Hours: 5:00 AM - 8:00 PM   │
│  📏 5.2 km from your location          │
│                                         │
├─────────────────────────────────────────┤
│  ⭐ About                                │
│     White marble Venkateswara temple... │
│                                         │
│  🎭 Festivals                            │
│     Annual Brahmotsavam, Vaikuntha...  │
│                                         │
│  🍚 Prasadam                             │
│     Free Tirupati Laddu available       │
│                                         │
├─────────────────────────────────────────┤
│  [🗺️ View on Map]  [🚗 Get Directions] │
│  [📅 Add to Yatra]  [📞 Call]          │
└─────────────────────────────────────────┘
```

### 7.3 Map Screen

```
┌─────────────────────────────────────────┐
│  🔍 Search...                    📍📷  │
├─────────────────────────────────────────┤
│                                         │
│     [Google Maps Full Screen]           │
│     • 10 temple markers (🕉️ icons)    │
│     • User location (blue dot)         │
│     • Route polylines                  │
│     • Info windows on tap              │
│                                         │
├─────────────────────────────────────────┤
│  📍 Showing: 10 temples                 │
│  [Filter: All Temples ▼]               │
│                                         │
├─────────────────────────────────────────┤
│  [📋 List View]  [🚗 Navigate]         │
└─────────────────────────────────────────┘
```

### 7.4 Route Planning Screen

```
┌─────────────────────────────────────────┐
│  Plan Your Yatra                 🔙    │
├─────────────────────────────────────────┤
│  🚗 Travel Mode: [Driving ▼]           │
│                                         │
│  📍 Select Temples:                     │
│  ☐ Birla Mandir                         │
│  ☐ Jagannath Temple                     │
│  ☐ Chilkur Balaji                       │
│  ☐ Keesaragutta                         │
│  ☐ Sanghi Temple                        │
│  [Add More...]                          │
│                                         │
├─────────────────────────────────────────┤
│  📏 Total Distance: 45.2 km             │
│  ⏱️ Estimated Time: 1h 45m              │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  Optimized Route:               │   │
│  │  1. Birla Mandir → Jagannath    │   │
│  │  2. Jagannath → ISKCON         │   │
│  │  3. ISKCON → Chilkur Balaji    │   │
│  │  ...                            │   │
│  └─────────────────────────────────┘   │
│                                         │
├─────────────────────────────────────────┤
│  [🗺️ Preview on Map]  [▶️ Start Nav]   │
└─────────────────────────────────────────┘
```

---

## 8. Offline Demo Mode Strategy

### 8.1 Fallback Data

Since Google Maps APIs have usage limits, implement offline demo mode:

```dart
class OfflineFallbackService {
  // Pre-cached temple data for demo
  static final List<Map<String, dynamic>> cachedTemples = [
    {
      'placeId': 'ChIJxxxxxxxxxxxx',
      'name': 'Birla Mandir, Hyderabad',
      'lat': 17.4061,
      'lng': 78.4686,
      'rating': 4.7,
      'address': 'Khairatabad, Hyderabad',
      'timings': '5:00 AM - 8:00 PM',
      'photoUrl': 'assets/images/birla_mandir.jpg',
    },
    // ... 9 more temples
  ];
  
  // Pre-computed distances for demo
  static final Map<String, Map<String, dynamic>> distances = {
    'birla_mandir': {
      'jagannath': {'km': 4.2, 'min': 15},
      'chilkur_balaji': {'km': 25.3, 'min': 45},
      // ... more distances
    },
  };
  
  // Pre-defined routes for demo
  static final List<List<double>> routePolylines = [
    // Encoded polylines for each route segment
  ];
}
```

### 8.2 Mode Switching

```dart
enum AppMode {
  online,      // Use Google APIs
  offlineDemo, // Use cached data
}

class AppModeService extends StateNotifier<AppMode> {
  AppModeService() : super(AppMode.online);
  
  void toggleDemoMode() {
    state = state == AppMode.online 
        ? AppMode.offlineDemo 
        : AppMode.online;
    
    // Show notification
    _showModeNotification();
  }
  
  bool get isOnline => state == AppMode.online;
}
```

---

## 9. Error Handling & Fallbacks

### 9.1 API Error Strategy

```dart
class ApiErrorHandler {
  static Widget buildErrorWidget(String error, VoidCallback onRetry) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.wifi_off, size: 64, color: Colors.orange),
        SizedBox(height: 16),
        Text('Unable to connect'),
        SizedBox(height: 8),
        Text('Showing cached data instead'),
        SizedBox(height: 16),
        ElevatedButton(
          onPressed: onRetry,
          child: Text('Retry'),
        ),
      ],
    );
  }
  
  static Future<T> withFallback<T>({
    required Future<T> Function() apiCall,
    required T fallbackData,
  }) async {
    try {
      return await apiCall();
    } catch (e) {
      print('API Error: $e');
      return fallbackData;
    }
  }
}
```

---

## 10. Success Criteria

### 10.1 Functional Requirements

- [ ] 10 Hyderabad temples displayed from Google Places
- [ ] Interactive Google Maps with temple markers
- [ ] Click-to-view temple details (photos, reviews, ratings)
- [ ] Multi-stop route optimization
- [ ] Distance and time estimates
- [ ] Turn-by-turn navigation instructions
- [ ] Voice guidance (TTS)
- [ ] Offline demo mode with cached data
- [ ] Graceful API error handling

### 10.2 Presentation Requirements

- [ ] Demo works without live API calls (offline mode)
- [ ] Clear visual distinction between online/offline states
- [ ] Smooth animations for route changes
- [ ] All features accessible within 2-3 taps
- [ ] Professional UI matching jury expectations

---

## 11. Estimated Timeline

| Phase | Duration | Total Days |
|-------|----------|------------|
| Phase 1: Setup & Directory | 2 days | 1-2 |
| Phase 2: Temple Details | 2 days | 3-4 |
| Phase 3: Interactive Map | 2 days | 5-6 |
| Phase 4: Routing & Navigation | 2 days | 7-8 |
| Phase 5: Demo Features | 1 day | 9 |
| **Total** | **9 days** | **~2 weeks** |

---

## 12. API Cost Considerations

### 12.1 Free Tier Limits

| API | Free Tier | Cost After |
|-----|-----------|------------|
| Maps SDK | Unlimited | - |
| Places API | 1,000 req/mo | $0.017/req |
| Directions API | 1,000 req/day | $0.005/req |
| Distance Matrix | 1,000 elem/req | $0.005/elem |

### 12.2 Cost Control

- Implement aggressive caching
- Use demo mode for presentations
- Monitor API usage in Google Cloud Console
- Set budget alerts at $50/month

---

*Updated Plan: Google Maps Platform Integration*
*Version 2.0 - February 2025*
