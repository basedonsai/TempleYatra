# Temple Yatra App

A comprehensive Flutter application for planning and experiencing temple yatras (pilgrimages) in India. This app provides features like yatra planning, temple details, audio guides, community features, and offline support.

## Features

- 🗺️ **Yatra Planner**: Plan your temple visits with customizable routes
- 🏛️ **Temple Details**: Comprehensive information about temples
- 🎧 **Audio Guides**: Listen to temple history and significance
- 👥 **Community**: Connect with other pilgrims
- 📦 **Offline Support**: Download content for offline access
- 🎨 **Modern UI**: Beautiful and intuitive interface

## Prerequisites

Before you begin, ensure you have the following installed:

1. **Flutter SDK** (3.10.1 or higher)
   - Download from [flutter.dev](https://flutter.dev/docs/get-started/install)
   - Add Flutter to your PATH

2. **Android Studio** or **Visual Studio Code**
   - Android Studio: [Download here](https://developer.android.com/studio)
   - VS Code: [Download here](https://code.visualstudio.com/) with Flutter extension

3. **Android SDK** (for Android development)
   - Install via Android Studio or standalone
   - Ensure Android SDK location is configured

4. **Git**
   - Download from [git-scm.com](https://git-scm.com/)

## Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/basedonsai/Temple-Yatra.git
cd Temple-Yatra
```

### 2. Install Flutter Dependencies

```bash
flutter pub get
```

### 3. Verify Flutter Installation

```bash
flutter doctor
```

Fix any issues reported by `flutter doctor` before proceeding.

### 4. Configure Android Emulator

#### Create a New Emulator (Recommended)

1. Open Android Studio
2. Go to **Tools** > **Device Manager**
3. Click **Create Device**
4. Select a phone model (e.g., Pixel 6)
5. Select a system image (e.g., API 36)
6. Give it a short, friendly name like `temple-yatra-emu`
7. Click **Finish**

#### List Available Emulators

```bash
flutter emulators
```

#### Launch the Emulator

```bash
flutter emulators --launch <emulator-id>
```

Example:
```bash
flutter emulators --launch temple-yatra-emu
```

> **Note**: Emulator names are configured locally on each developer's machine and cannot be synced via Git. Each team member should create their own emulator with a name they prefer.

### 5. Run the App

#### Using Command Line

```bash
flutter run
```

#### Using VS Code

1. Open the project in VS Code
2. Press `F5` or click **Run** > **Start Debugging**
3. Select your device/emulator from the device selector

#### Using Android Studio

1. Open the project in Android Studio
2. Select your emulator from the device dropdown
3. Click the **Run** button (green triangle)

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── screens/                  # All screen widgets
│   ├── onboarding_screen.dart
│   ├── home_screen.dart
│   ├── temple_detail_screen.dart
│   ├── yatra_planner_screen.dart
│   ├── audio_guide_screen.dart
│   ├── community_screen.dart
│   └── offline_pack_manager_screen.dart
└── theme/
    └── app_theme.dart        # App theme configuration
```

## Common Issues & Solutions

### Issue: "SDK location not found"

**Solution**: Create `android/local.properties` file (this file is git-ignored):

```properties
sdk.dir=C:\\Users\\YourUsername\\AppData\\Local\\Android\\Sdk
```

Replace `YourUsername` with your actual Windows username.

### Issue: Emulator not showing up

**Solution**:
1. Ensure the emulator is running: `flutter emulators --launch <emulator-id>`
2. Check devices: `flutter devices`
3. Restart VS Code/Android Studio

### Issue: Build failures

**Solution**:
```bash
flutter clean
flutter pub get
flutter run
```

## Development Workflow

### Before Making Changes

```bash
git checkout -b feature/your-feature-name
```

### After Making Changes

```bash
git add .
git commit -m "Description of your changes"
git push origin feature/your-feature-name
```

Then create a Pull Request on GitHub.

## Testing

Run tests:
```bash
flutter test
```

## Building for Release

### Android APK

```bash
flutter build apk --release
```

### Android App Bundle

```bash
flutter build appbundle --release
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## Team Setup Checklist

- [ ] Flutter SDK installed and configured
- [ ] Android Studio/VS Code installed
- [ ] Android SDK configured
- [ ] Repository cloned
- [ ] Dependencies installed (`flutter pub get`)
- [ ] Emulator created and tested
- [ ] App runs successfully

## Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Documentation](https://dart.dev/guides)
- [Material Design Guidelines](https://material.io/design)

## License

This project is private and intended for educational purposes.

## Support

For issues or questions, please create an issue on GitHub or contact the development team.
