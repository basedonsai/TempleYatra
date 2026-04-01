# Temple Yatra

Flutter app for planning and experiencing temple pilgrimages — route planning, temple details, audio guides, and community features.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) `^3.10.1`
- [Android Studio](https://developer.android.com/studio) with Flutter & Dart plugins installed
- Android SDK + Emulator (via Android Studio Device Manager)
- Google Maps API key

## Setup

### 1. Accept Android licenses

```bash
flutter doctor --android-licenses
flutter doctor
```

Resolve any issues before continuing.

### 2. Create an emulator

In Android Studio: `Tools > Device Manager > Create Device`
Recommended: Pixel 6, API 35

### 3. Create local config files

`android/local.properties` (git-ignored):
```properties
sdk.dir=C:\Users\YourUsername\AppData\Local\Android\Sdk
```

`.env` in project root (git-ignored):
```
GOOGLE_MAPS_API_KEY=your_key_here
GROQ_API_KEY
```

### 4. Install dependencies and run

```bash
flutter pub get
flutter run
```

## Project Structure

```
lib/
├── main.dart
├── data/          # Seed data (used only by DatabaseSeeder)
├── database/      # SQLite repositories and providers
├── models/        # Data models
├── providers/     # Riverpod providers
├── screens/       # UI screens
├── services/      # Business logic
├── theme/         # App theme
├── utils/         # Utilities
└── widgets/       # Shared widgets
```

## Common Issues

**"SDK location not found"** — Create `android/local.properties` as shown above.

**Build failures** — `flutter clean && flutter pub get && flutter run`

**Emulator not detected** — `flutter devices`

## Release Builds

```bash
flutter build apk --release        # APK
flutter build appbundle --release  # App Bundle
```
