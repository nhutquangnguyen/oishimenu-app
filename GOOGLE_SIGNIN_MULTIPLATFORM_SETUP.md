# Google Sign-In Multi-Platform Setup Guide

Your Flutter restaurant management app now supports Google Sign-In across **iOS, Android, and Web**! 🎉

## 🎯 What's Already Implemented

✅ **iOS Configuration**
- GoogleService-Info.plist with real Firebase configuration
- URL schemes configured in Info.plist
- iOS-specific Google Sign-In implementation

✅ **Android Configuration**
- Application ID updated to `com.oishimenu.app`
- Google Services plugin added to build.gradle.kts
- Android-specific Google Sign-In configuration

✅ **Web Configuration**
- Google APIs scripts added to index.html
- Web-specific Google Sign-In implementation

✅ **Multi-Platform Dart Code**
- Platform detection and configuration
- Unified authentication flow through Supabase
- Cross-platform compatibility

## 🔧 Final Setup Steps

To complete the Google Sign-In setup, you need to configure OAuth clients in Google Cloud Console and Supabase.

### 1. Google Cloud Console Setup

Go to [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials

#### Create OAuth 2.0 Client IDs:

**A. iOS Application**
```
Application type: iOS
Bundle ID: com.oishimenu.app
```

**B. Android Application**
```
Application type: Android
Package name: com.oishimenu.app
SHA-1 certificate fingerprint: [Get from: keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore]
```

**C. Web Application**
```
Application type: Web application
Authorized JavaScript origins: https://yourdomain.com
Authorized redirect URIs: https://your-supabase-project.supabase.co/auth/v1/callback
```

### 2. Download Configuration Files

#### For Android:
1. Download `google-services.json` from Firebase Console
2. Place it in: `android/app/google-services.json`

#### For iOS:
✅ Already completed - `ios/Runner/GoogleService-Info.plist` is configured

### 3. Update Client IDs

In `lib/services/supabase_service.dart`, replace the placeholder client IDs:

```dart
// Replace these with your actual OAuth 2.0 Client IDs
const webClientId = 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';
const iosClientId = 'YOUR_IOS_CLIENT_ID.apps.googleusercontent.com';
```

### 4. Update iOS Info.plist

In `ios/Runner/Info.plist`, update the REVERSED_CLIENT_ID:

```xml
<string>com.googleusercontent.apps.YOUR_ACTUAL_REVERSED_CLIENT_ID</string>
```

### 5. Configure Supabase Dashboard

1. Go to your Supabase project dashboard
2. Navigate to Authentication → Settings → Auth Providers
3. Enable Google OAuth
4. Add your credentials:
   - **Client ID**: Use the Web Application Client ID
   - **Client Secret**: From the Web Application credentials
5. Add redirect URL: `https://your-project-ref.supabase.co/auth/v1/callback`

## 📱 Platform-Specific Features

### iOS
- Uses `CLIENT_ID` from GoogleService-Info.plist
- Supports native iOS Google Sign-In flow
- Proper URL scheme handling

### Android
- Uses `google-services.json` configuration
- SHA-1 fingerprint verification
- Native Android Google Sign-In flow

### Web
- Uses Web Client ID for authentication
- JavaScript-based Google Sign-In
- Works in all modern browsers

## 🚀 Testing Your Implementation

### 1. Run on iOS Simulator
```bash
flutter run -d ios
```

### 2. Run on Android Emulator/Device
```bash
flutter run -d android
```

### 3. Run on Web
```bash
flutter run -d web-server --web-port 8080
```

### 4. Test Google Sign-In Flow
1. Navigate to login page
2. Tap "Continue with Google"
3. Complete authentication flow
4. Verify user appears in Supabase Auth dashboard

## 🎯 Current Implementation Details

### File Structure
```
├── ios/Runner/
│   ├── GoogleService-Info.plist     ✅ Real Firebase config
│   └── Info.plist                   ✅ URL schemes configured
├── android/app/
│   ├── build.gradle.kts             ✅ Google Services plugin
│   └── google-services.json         ❓ Needs download from Firebase
├── web/
│   └── index.html                   ✅ Google APIs included
└── lib/services/
    └── supabase_service.dart        ✅ Multi-platform implementation
```

### Authentication Flow
1. **User taps Google Sign-In button**
2. **Platform detection** (iOS/Android/Web)
3. **Platform-specific GoogleSignIn configuration**
4. **Google OAuth flow** (native or web)
5. **Token exchange with Supabase**
6. **User session creation**
7. **Navigation to dashboard**

## 🔍 Troubleshooting

### Common Issues:

**iOS:**
- Ensure REVERSED_CLIENT_ID matches GoogleService-Info.plist
- Check URL scheme configuration in Info.plist

**Android:**
- Verify SHA-1 fingerprint matches Google Cloud Console
- Ensure google-services.json is in correct location
- Check package name consistency

**Web:**
- Verify authorized JavaScript origins
- Check redirect URI configuration
- Ensure web client ID is correct

**All Platforms:**
- Confirm Supabase Auth Provider configuration
- Verify client IDs are correctly set in Dart code
- Check Supabase project settings

## 📋 Setup Checklist

- [ ] Create OAuth clients in Google Cloud Console (iOS, Android, Web)
- [ ] Download google-services.json for Android
- [ ] Update client IDs in `supabase_service.dart`
- [ ] Update REVERSED_CLIENT_ID in iOS Info.plist
- [ ] Configure Supabase Google Auth Provider
- [ ] Test on all target platforms
- [ ] Verify users appear in Supabase dashboard

## 🎉 What You'll Have

After completing these steps, your users can:
- **Sign in with Google** on iOS devices
- **Sign in with Google** on Android devices
- **Sign in with Google** in web browsers
- **Seamless experience** across all platforms
- **Unified user management** through Supabase

Your restaurant management app will support the most popular authentication method across all major platforms! 🚀

## 📞 Need Help?

If you encounter issues:
1. Check the console logs for specific error messages
2. Verify all client IDs match between platforms
3. Ensure redirect URIs are correctly configured
4. Test with a simple Google Sign-In first before full integration

Happy authenticating! 🔐✨