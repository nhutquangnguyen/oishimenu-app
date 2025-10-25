# 🚀 Supabase Migration Guide for OishiMenu

This guide will help you migrate your OishiMenu Flutter app from SQLite to Supabase.

## 📋 Prerequisites

1. **Supabase Account**: Sign up at [supabase.com](https://supabase.com)
2. **Flutter Environment**: Ensure Flutter is properly set up

## 🔧 Step 1: Create Supabase Project

1. Go to [app.supabase.com](https://app.supabase.com)
2. Click "New Project"
3. Fill in your project details:
   - **Name**: `oishimenu-restaurant`
   - **Database Password**: Create a strong password
   - **Region**: Choose closest to your location
4. Wait for project to be created (2-3 minutes)

## 🏗️ Step 2: Setup Database Schema

1. In your Supabase dashboard, go to **SQL Editor**
2. Open the file `supabase_schema.sql` from your project root
3. Copy and paste the entire SQL content into the Supabase SQL Editor
4. Click **Run** to execute the schema

This will create:
- ✅ 15 database tables with proper relationships
- ✅ Indexes for performance optimization
- ✅ Row Level Security (RLS) policies
- ✅ Auto-updating timestamps
- ✅ Sample data (categories and order sources)

## 🔑 Step 3: Configure API Keys

1. In Supabase dashboard, go to **Settings → API**
2. Copy your **Project URL** and **anon public key**
3. Open `lib/core/config/supabase_config.dart`
4. Replace the placeholder values:

```dart
class SupabaseConfig {
  static const String url = 'https://your-project-id.supabase.co';
  static const String anonKey = 'your-anon-key-here';
  // ... rest of the code
}
```

## 📦 Step 4: Install Dependencies

Run this command in your project root:

```bash
flutter pub get
```

This will install:
- `supabase_flutter: ^2.5.6` - Supabase Flutter SDK
- All existing dependencies remain the same

## 🔄 Step 5: Replace Services (Gradual Migration)

### Option A: Complete Migration (Recommended)
Replace all SQLite services with Supabase services:

1. **Menu Service**: Replace `MenuService` with `SupabaseMenuService`
2. **Order Service**: Replace `OrderService` with `SupabaseOrderService`
3. **Customer Service**: Replace `CustomerService` with `SupabaseCustomerService`

### Option B: Hybrid Approach
Keep both systems running temporarily:
- Use Supabase for new data
- Migrate existing SQLite data gradually
- Switch services one feature at a time

## 🛠️ Step 6: Update Service Providers

In your Riverpod providers, replace the service instances:

```dart
// OLD
final menuServiceProvider = Provider<MenuService>((ref) => MenuService());

// NEW
final menuServiceProvider = Provider<SupabaseMenuService>((ref) => SupabaseMenuService());
```

## 🔐 Step 7: Authentication Setup

### Enable Authentication Providers
1. In Supabase dashboard, go to **Authentication → Providers**
2. Enable **Email** provider
3. Configure any social providers you want (Google, Facebook, etc.)

### Update Your Auth Code
```dart
// Use SupabaseAuthService instead of current AuthService
final authService = SupabaseAuthService();
```

## 📊 Step 8: Data Migration (Optional)

If you have existing SQLite data, create a migration script:

```dart
// Example migration function
Future<void> migrateFromSQLiteToSupabase() async {
  final sqliteService = MenuService(); // Your old service
  final supabaseService = SupabaseMenuService(); // New service

  // Get existing data
  final existingMenuItems = await sqliteService.getMenuItems();

  // Migrate to Supabase
  for (final item in existingMenuItems) {
    await supabaseService.createMenuItem(item);
  }
}
```

## 🚦 Step 9: Testing

### Test Basic Operations
1. **Menu Items**: Create, read, update, delete
2. **Orders**: Create new orders, update status
3. **Customers**: Add new customers, search by phone
4. **Authentication**: Sign up, sign in, sign out

### Real-time Features (Bonus)
Supabase provides real-time subscriptions:

```dart
// Listen to new orders in real-time
SupabaseService.client
  .from('orders')
  .stream(primaryKey: ['id'])
  .listen((data) {
    // Update UI when new orders arrive
  });
```

## 🌟 Benefits You'll Get

### 🚀 **Performance**
- **Faster queries** with PostgreSQL optimization
- **CDN-backed** for global performance
- **Connection pooling** for better resource usage

### 🔒 **Security**
- **Row Level Security** (RLS) built-in
- **JWT-based authentication**
- **Database rules** to prevent unauthorized access

### 📱 **Real-time Features**
- **Live order updates** across devices
- **Inventory tracking** in real-time
- **Multi-user collaboration**

### ☁️ **Cloud Benefits**
- **Automatic backups**
- **Scalability** - handles more customers automatically
- **No local database management**

### 🔄 **Advanced Features**
- **API auto-generation**
- **Database functions** for complex operations
- **File storage** for menu item photos
- **Edge functions** for custom backend logic

## 🆘 Troubleshooting

### Common Issues

**1. Connection Error**
```
Error: Invalid API key
```
- Check your `supabase_config.dart` file
- Ensure URL and anon key are correct
- Verify project is not paused

**2. Database Schema Error**
```
Error: relation "menu_items" does not exist
```
- Run the `supabase_schema.sql` in SQL Editor
- Check all tables were created successfully

**3. Authentication Error**
```
Error: Email authentication is disabled
```
- Enable Email provider in Supabase dashboard
- Check authentication policies

### Getting Help

1. **Supabase Docs**: [docs.supabase.com](https://docs.supabase.com)
2. **Community**: [supabase.com/discord](https://supabase.com/discord)
3. **GitHub Issues**: Report bugs in your project repo

## 🎯 Next Steps

After successful migration:

1. **Remove SQLite Dependencies** (optional):
   ```bash
   # Remove from pubspec.yaml
   # sqflite: ^2.4.2
   # sqflite_common_ffi: ^2.3.0
   ```

2. **Setup Production Environment**:
   - Create separate Supabase projects for staging/production
   - Configure environment-specific config files

3. **Add Advanced Features**:
   - Real-time order notifications
   - File uploads for menu photos
   - Advanced analytics with Supabase functions

4. **Performance Optimization**:
   - Add database indexes for your specific queries
   - Implement caching strategies
   - Optimize API calls

## 📈 Monitoring & Analytics

Supabase provides built-in monitoring:
- **Database performance** metrics
- **API usage** statistics
- **Authentication** analytics
- **Real-time** connection monitoring

Access these in your Supabase dashboard under **Reports**.

---

**🎉 Congratulations!** Your restaurant management system is now powered by Supabase's enterprise-grade infrastructure. You can now scale to thousands of orders and customers with real-time synchronization across all devices!