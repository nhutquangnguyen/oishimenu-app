# OishiMenu Flutter App - Setup Guide

This guide will help you get the OishiMenu Flutter app up and running on your machine.

## Prerequisites Checklist

### ✅ 1. Flutter Installation
- [x] Installing Flutter via Homebrew (in progress)
- [ ] Verify Flutter installation
- [ ] Run Flutter doctor to check environment

### ❓ 2. Development Tools
You'll need ONE of these IDEs:
- [ ] **VS Code** (Recommended) - Lightweight and fast
- [ ] **Android Studio** - Full-featured with built-in emulator
- [ ] **IntelliJ IDEA** - Alternative option

### ❓ 3. Device/Simulator Setup
Choose ONE option for testing:
- [ ] **iOS Simulator** (if you have Xcode installed)
- [ ] **Android Emulator** (requires Android Studio)
- [ ] **Physical Device** (iOS or Android with debugging enabled)
- [ ] **Chrome Browser** (for web testing)

### ❓ 4. Firebase Project
- [ ] Create Firebase project at https://console.firebase.google.com
- [ ] Enable Authentication (Email/Password)
- [ ] Enable Firestore Database
- [ ] Enable Firebase Storage
- [ ] Download configuration files

## Step-by-Step Setup

### Step 1: Verify Flutter Installation

Once Flutter finishes installing, run:

```bash
# Check Flutter installation
flutter --version

# Check for any issues
flutter doctor

# Accept Android licenses (if needed)
flutter doctor --android-licenses
```

### Step 2: Install Project Dependencies

```bash
# Navigate to project directory
cd /Users/macbook/Projects/github/P/oishimenu-app-flutter

# Get Flutter packages
flutter pub get
```

### Step 3: Firebase Configuration

#### A. Create Firebase Project
1. Go to https://console.firebase.google.com
2. Click "Create a project"
3. Name it "oishimenu-app" (or your preferred name)
4. Enable Google Analytics (optional)

#### B. Enable Firebase Services
1. **Authentication**:
   - Go to Authentication → Sign-in method
   - Enable "Email/Password"

2. **Firestore Database**:
   - Go to Firestore Database → Create database
   - Start in "test mode" for now

3. **Storage**:
   - Go to Storage → Get started
   - Start in "test mode"

#### C. Add Mobile Apps to Firebase
1. Click "Add app" → Choose iOS or Android
2. Follow the setup instructions
3. Download the configuration files:
   - **Android**: `google-services.json`
   - **iOS**: `GoogleService-Info.plist`

#### D. Update Configuration Files

**For Android:**
1. Place `google-services.json` in `android/app/`
2. Update `android/app/build.gradle` (if needed)

**For iOS:**
1. Place `GoogleService-Info.plist` in `ios/Runner/`
2. Update iOS configuration (if needed)

**For Flutter:**
Update `lib/core/config/firebase_options.dart` with your project details:

```dart
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'your-android-api-key',
  appId: 'your-android-app-id',
  messagingSenderId: 'your-messaging-sender-id',
  projectId: 'your-project-id',
  storageBucket: 'your-project-id.appspot.com',
);

static const FirebaseOptions ios = FirebaseOptions(
  apiKey: 'your-ios-api-key',
  appId: 'your-ios-app-id',
  messagingSenderId: 'your-messaging-sender-id',
  projectId: 'your-project-id',
  storageBucket: 'your-project-id.appspot.com',
  iosBundleId: 'com.oishimenu.oishimenuApp',
);
```

### Step 4: Test the App

```bash
# Check connected devices
flutter devices

# Run the app
flutter run

# Or run on specific device
flutter run -d chrome        # Web browser
flutter run -d macos         # macOS app
flutter run -d ios           # iOS simulator
flutter run -d android       # Android emulator
```

## IDE Setup Recommendations

### VS Code (Recommended)
1. Install VS Code from https://code.visualstudio.com
2. Install Flutter extension
3. Install Dart extension
4. Open project: `code /Users/macbook/Projects/github/P/oishimenu-app-flutter`

### Android Studio
1. Download from https://developer.android.com/studio
2. Install Flutter plugin
3. Install Dart plugin
4. Open project folder

## Common Issues & Solutions

### Issue: Flutter not found in PATH
**Solution**: Add Flutter to your PATH:
```bash
echo 'export PATH="$PATH:/opt/homebrew/bin/flutter/bin"' >> ~/.zshrc
source ~/.zshrc
```

### Issue: Android licenses not accepted
**Solution**:
```bash
flutter doctor --android-licenses
```

### Issue: No devices available
**Solutions**:
- **iOS**: Install Xcode from App Store, then run: `open -a Simulator`
- **Android**: Install Android Studio, create AVD (Android Virtual Device)
- **Web**: Make sure Chrome is installed

### Issue: Firebase configuration errors
**Solution**: Double-check:
- Configuration files are in correct locations
- Project IDs match between Firebase console and code
- All required services are enabled in Firebase

## Next Steps After Setup

1. **Test Authentication**: Try signup/login functionality
2. **Explore Features**: Navigate through dashboard, menu, orders, etc.
3. **Add Test Data**: Create sample menu items and orders
4. **Customize**: Modify colors, branding, and content to match your restaurant

## Development Workflow

```bash
# Start development
flutter run

# Hot reload (press 'r' in terminal while app is running)
# Hot restart (press 'R' in terminal)

# Format code
flutter format .

# Analyze code
flutter analyze

# Run tests
flutter test
```

## Getting Help

- **Flutter Documentation**: https://docs.flutter.dev
- **Firebase Documentation**: https://firebase.google.com/docs
- **Project Issues**: Check the README.md for troubleshooting

---

**Ready to proceed?**
1. Wait for Flutter installation to complete
2. Follow steps 1-4 above
3. Run `flutter run` to see your restaurant management app in action! 🚀