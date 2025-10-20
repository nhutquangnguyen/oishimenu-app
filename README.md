# OishiMenu Flutter App

A mobile Flutter application converted from the OishiMenu web app - a comprehensive restaurant management system for Vietnamese F&B SMEs.

## Overview

This Flutter app provides mobile-friendly access to the OishiMenu restaurant management platform, featuring:

- **Dashboard** - Real-time KPIs, sales charts, and business overview
- **POS System** - Point of sale for quick order processing
- **Menu Management** - Full CRUD operations for menu items, categories, and options
- **Order Management** - Multi-channel order tracking and status updates
- **Inventory Management** - Ingredient tracking, stock alerts, and stocktake sessions
- **Employee Management** - Staff directory and role management
- **Customer Feedback** - Review management and response system
- **Analytics** - Business insights and reporting

## Architecture

### Technology Stack

- **Frontend**: Flutter 3.x with Material Design 3
- **State Management**: Riverpod for reactive state management
- **Backend**: Firebase (Firestore, Auth, Storage)
- **Navigation**: Go Router for declarative routing
- **Charts**: FL Chart for data visualization
- **Internationalization**: Easy Localization (English/Vietnamese)
- **Local Storage**: Hive for offline capabilities

### Project Structure

```
lib/
├── core/                    # Core app configuration
│   ├── config/             # Firebase, theme, and app config
│   ├── constants/          # App constants and enums
│   ├── router/             # Go Router configuration
│   └── widgets/            # Shared widgets (layout, etc.)
├── features/               # Feature-based modules
│   ├── auth/               # Authentication (login, signup)
│   ├── dashboard/          # Main dashboard with KPIs
│   ├── menu/               # Menu management
│   ├── orders/             # Order processing
│   ├── pos/                # Point of sale system
│   ├── inventory/          # Inventory and stocktake
│   ├── employees/          # Staff management
│   ├── feedback/           # Customer feedback
│   └── analytics/          # Business analytics
├── models/                 # Data models (Order, MenuItem, etc.)
├── services/              # Firebase services
└── providers/             # Riverpod providers
```

### Data Models

Key data models include:

- **MenuItem**: Menu items with categories, photos, options, and pricing
- **Order**: Orders with items, customer info, status, and payments
- **Customer**: Customer information and delivery details
- **Employee**: Staff members with roles and permissions
- **Inventory**: Ingredients, recipes, and stock tracking

## Features Converted from Web App

### ✅ Completed Features

1. **Authentication System**
   - Email/password login and signup
   - Firebase Auth integration
   - Protected route navigation
   - User session management

2. **Dashboard**
   - Revenue, orders, and customer metrics
   - Interactive sales charts
   - Quick action buttons
   - Recent orders display

3. **App Structure**
   - Material Design 3 theme
   - Bottom navigation layout
   - Responsive mobile UI
   - Dark/light theme support

4. **Internationalization**
   - English and Vietnamese support
   - Easy Localization setup
   - Locale switching capability

### 🚧 In Progress Features

1. **Menu Management**
   - Menu items CRUD operations
   - Category management
   - Option groups and customizations
   - Photo upload and management

2. **Order Processing**
   - Real-time order tracking
   - Multi-platform integration
   - Status workflow management
   - Customer information handling

3. **POS System**
   - Menu grid interface
   - Cart management
   - Payment processing
   - Receipt generation

4. **Inventory Management**
   - Ingredient tracking
   - Stock alerts
   - Stocktake sessions
   - Cost calculations

### 📋 Planned Features

1. **Employee Management**
   - Staff directory
   - Role-based permissions
   - Shift scheduling
   - Performance tracking

2. **Customer Feedback**
   - Review collection
   - Response management
   - Rating analytics
   - Sentiment tracking

3. **Advanced Analytics**
   - Business intelligence
   - Financial reporting
   - Performance metrics
   - Trend analysis

## Getting Started

### Prerequisites

- Flutter SDK 3.x or higher
- Dart SDK 3.x or higher
- Firebase project with Firestore, Auth, and Storage enabled
- Android Studio / VS Code with Flutter extensions

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd oishimenu-app-flutter
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a Firebase project
   - Add Android/iOS apps to the project
   - Download and place `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Update `lib/core/config/firebase_options.dart` with your project credentials

4. **Run the app**
   ```bash
   flutter run
   ```

### Firebase Setup

Update the Firebase configuration in `lib/core/config/firebase_options.dart`:

```dart
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'your-android-api-key',
  appId: 'your-android-app-id',
  messagingSenderId: 'your-messaging-sender-id',
  projectId: 'your-project-id',
  storageBucket: 'your-project-id.appspot.com',
);
```

### Environment Configuration

The app supports the following environment variables:

- Firebase configuration (API keys, project IDs)
- App-specific settings (debug mode, analytics)

## Development

### State Management

The app uses Riverpod for state management:

```dart
// Provider example
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// Consumer widget example
class DashboardPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    // ... build UI
  }
}
```

### Navigation

Go Router provides type-safe navigation:

```dart
// Navigate to a page
context.go('/dashboard');

// Navigate with parameters
context.go('/order/detail/${orderId}');
```

### Internationalization

Use Easy Localization for translations:

```dart
Text('welcome'.tr()),  // Gets translation for current locale
```

## Testing

Run tests with:

```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test/
```

## Building for Production

### Android

```bash
flutter build apk --release
# or
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
```

## Deployment

The app can be deployed to:

- **Android**: Google Play Store
- **iOS**: Apple App Store
- **Firebase App Distribution**: For testing and beta releases

## Performance Considerations

- **Lazy loading**: Features are loaded on-demand
- **Caching**: Local storage with Hive for offline support
- **Image optimization**: Cached network images with placeholder
- **State management**: Efficient Riverpod providers prevent unnecessary rebuilds

## Security

- **Firebase Security Rules**: Protect user data at database level
- **Authentication**: Secure user sessions with Firebase Auth
- **Data validation**: Client and server-side input validation
- **Network security**: HTTPS-only communications

## Contributing

1. Fork the repository
2. Create a feature branch
3. Implement changes following Flutter best practices
4. Add tests for new functionality
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support, contact:
- Technical issues: Create an issue on GitHub
- Business inquiries: Contact OishiMenu support

---

**Note**: This Flutter app is a mobile-friendly conversion of the OishiMenu web application, designed specifically for restaurant management on mobile devices.