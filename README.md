# Temple Yatra App

A Flutter app for planning and experiencing temple pilgrimages in India — with route planning, temple details, audio guides, and community features.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install/windows/mobile) (SDK `^3.10.1`)
- [Android Studio](https://developer.android.com/studio) with Flutter & Dart plugins
- Android SDK + Emulator (installed via Android Studio)
- A Google Maps API key (for maps and directions)

## First-Time Setup

### 1. Install Flutter & Android Studio

After installing both, open Android Studio and go to `File > Settings > Plugins` and install the **Flutter** plugin (Dart installs automatically).

### 2. Accept Android licenses

```bash
flutter doctor --android-licenses
flutter doctor
```

Fix any remaining issues `flutter doctor` reports before continuing.

### 3. Create an Android Emulator

In Android Studio: `Tools > Device Manager > Create Device`
- Recommended: Pixel 6, API 35

### 4. Configure local files

Create `android/local.properties` (git-ignored, each dev needs their own):
```properties
sdk.dir=C:\Users\YourUsername\AppData\Local\Android\Sdk
```

Create `.env` in the project root (git-ignored):
```
GOOGLE_MAPS_API_KEY=your_key_here
```

### 5. Install dependencies & run

```bash
flutter pub get
flutter run
```

## Project Structure

```
lib/
├── main.dart
├── data/          # Static data sources
├── models/        # Data models
├── providers/     # Riverpod state management
├── screens/       # UI screens
└── services/      # Business logic & API calls
```

## Common Issues

**"SDK location not found"** — Create `android/local.properties` as shown above.

**Build failures** — Run `flutter clean && flutter pub get && flutter run`.

**Emulator not detected** — Run `flutter devices` to confirm it's visible.

## Building for Release

```bash
# APK
flutter build apk --release

# App Bundle
flutter build appbundle --release
```
