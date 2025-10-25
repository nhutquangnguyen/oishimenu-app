# Google Sign-In Setup Guide

Google Sign-In has been successfully integrated into your Flutter restaurant management app! Follow these steps to complete the setup.

## 🎉 What's Already Done

✅ Added `google_sign_in` dependency to `pubspec.yaml`
✅ Implemented Google Sign-In in Supabase authentication service
✅ Added Google Sign-In buttons to login and signup pages
✅ Configured iOS project with required URL schemes
✅ Created template GoogleService-Info.plist file

## 🔧 Setup Required

### 1. Create Firebase Project (if not already done)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or use existing one
3. Enable Google Sign-In in Authentication → Sign-in method
4. Add your iOS app with bundle ID: `com.oishimenu.app`

### 2. Configure Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Navigate to APIs & Services → Credentials
3. Create OAuth 2.0 Client IDs for:
   - **iOS application** (use your bundle ID)
   - **Web application** (for Supabase)

### 3. Update Configuration Files

#### A. Replace iOS Client ID in SupabaseService
In `lib/services/supabase_service.dart`, update these lines:
```dart
const webClientId = 'YOUR_WEB_CLIENT_ID'; // Replace with actual web client ID
const iosClientId = 'YOUR_IOS_CLIENT_ID'; // Replace with actual iOS client ID
```

#### B. Update GoogleService-Info.plist
1. Download the real `GoogleService-Info.plist` from Firebase Console
2. Replace `/ios/Runner/GoogleService-Info.plist` with the downloaded file
3. Make sure it's added to the iOS project in Xcode

#### C. Update Info.plist
In `/ios/Runner/Info.plist`, replace `YOUR_REVERSED_CLIENT_ID` with the actual value from GoogleService-Info.plist:
```xml
<string>com.googleusercontent.apps.YOUR_ACTUAL_REVERSED_CLIENT_ID</string>
```

### 4. Configure Supabase Dashboard

1. Go to your Supabase project dashboard
2. Navigate to Authentication → Settings → Auth Providers
3. Enable Google OAuth
4. Add your Google OAuth credentials:
   - **Client ID**: Use the Web Application Client ID from Google Cloud Console
   - **Client Secret**: From the same web application credentials
5. Add authorized redirect URLs:
   - `https://your-project-ref.supabase.co/auth/v1/callback`

### 5. Test the Integration

1. Run the app: `flutter run`
2. Navigate to login page
3. Tap "Continue with Google"
4. Complete Google authentication flow
5. Verify user is created in Supabase Auth dashboard

## 📝 Example Configuration

### Google Cloud Console OAuth 2.0 Client IDs needed:
```
1. iOS Application:
   - Application type: iOS
   - Bundle ID: com.oishimenu.app

2. Web Application:
   - Application type: Web application
   - Authorized redirect URIs: https://your-project-ref.supabase.co/auth/v1/callback
```

### Supabase Auth Provider Settings:
```
Provider: Google
Client ID: [Web Application Client ID from Google Cloud]
Client Secret: [Web Application Client Secret from Google Cloud]
```

## 🚨 Important Notes

1. **Bundle ID**: Make sure your iOS bundle ID matches across Firebase, Google Cloud Console, and your iOS project
2. **Redirect URLs**: The Supabase redirect URL must be exactly: `https://your-project-ref.supabase.co/auth/v1/callback`
3. **Client IDs**: iOS app uses the iOS Client ID, but Supabase uses the Web Client ID
4. **GoogleService-Info.plist**: Must be properly added to the iOS project in Xcode, not just the file system

## 🔍 Troubleshooting

### Common Issues:
1. **"OAuth client not found"**: Check that Client IDs match between code and Google Cloud Console
2. **"Invalid redirect URI"**: Verify the redirect URL in Supabase matches Google Cloud Console settings
3. **"Bundle ID mismatch"**: Ensure Bundle ID is consistent across all platforms
4. **iOS build errors**: Make sure GoogleService-Info.plist is added to the iOS project in Xcode

### Testing Checklist:
- [ ] Firebase project created with iOS app
- [ ] Google Cloud Console OAuth clients created
- [ ] Supabase Google provider configured
- [ ] Real GoogleService-Info.plist in place
- [ ] Info.plist updated with correct REVERSED_CLIENT_ID
- [ ] SupabaseService updated with real client IDs
- [ ] App builds and runs without errors
- [ ] Google Sign-In button appears on login/signup pages
- [ ] Google authentication flow completes successfully
- [ ] User appears in Supabase Auth dashboard

## 🎯 Current Status

Your app now has:
- ✅ Google Sign-In UI components
- ✅ Complete authentication flow
- ✅ Supabase integration
- ✅ User management
- ✅ Cross-platform support (iOS configured, Android ready)

Just complete the configuration steps above and your users will be able to sign in with their Google accounts!