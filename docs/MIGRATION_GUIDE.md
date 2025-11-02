# Migration Guide: Cursor Sync → Hybrid Sync

This guide provides step-by-step instructions for migrating from the current complex cursor-based sync system to the new hybrid real-time sync system.

## Prerequisites

- Database admin access (Supabase dashboard)
- Flutter development environment
- Access to multiple test devices/browsers
- Backup of current code

## Migration Timeline

**Total estimated time: 1-2 days**
- Day 1: Database setup + core implementation
- Day 2: Testing + gradual rollout

## Step-by-Step Migration

### Phase 1: Database Setup (30 minutes)

#### 1.1 Apply Database Schema

**Execute SQL in Supabase Dashboard:**

1. Go to Supabase Dashboard → SQL Editor
2. Run the following script:

```sql
-- Copy and paste the entire contents of:
-- database/hybrid_sync_schema.sql
```

**Verification:**
```sql
-- Check if sync_metadata table exists
SELECT * FROM sync_metadata;

-- Check if triggers are installed
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE trigger_name LIKE '%sync%';

-- Test RPC function
SELECT rpc_get_sync_metadata('orders_last_updated');
```

**Expected output:**
- `sync_metadata` table with `orders_last_updated` record
- Two triggers: `trigger_orders_sync` and `trigger_order_items_sync`
- RPC function returns timestamp and version

#### 1.2 Test Database Triggers

```sql
-- Make a test change
UPDATE orders SET notes = 'test' WHERE id = (SELECT id FROM orders LIMIT 1);

-- Check if sync metadata was updated
SELECT * FROM sync_metadata WHERE key = 'orders_last_updated';
-- Version should have incremented
```

### Phase 2: Code Implementation (2-3 hours)

#### 2.1 Add Required Dependencies

**In `pubspec.yaml`:**
```yaml
dependencies:
  # Add if not already present
  shared_preferences: ^2.2.2
  # connectivity_plus: ^4.0.2  # Optional for network monitoring
```

Run: `flutter pub get`

#### 2.2 Initialize HybridSyncManager

**In your main app initialization (e.g., `main.dart`):**

```dart
import 'package:your_app/core/sync/hybrid_sync_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase first
  await Supabase.initialize(/* your config */);

  // Initialize hybrid sync manager
  try {
    final syncManager = HybridSyncManager();
    await syncManager.initialize();
    print('✅ Hybrid sync initialized successfully');
  } catch (e) {
    print('❌ Failed to initialize hybrid sync: $e');
    // Fallback to old system or show error
  }

  runApp(MyApp());
}
```

#### 2.3 Feature Flag Implementation

**Create a feature flag system:**

```dart
// lib/core/config/feature_flags.dart
class FeatureFlags {
  static bool get useHybridSync {
    // For testing, return true
    // In production, use remote config
    return true;

    // Or use Firebase Remote Config:
    // return FirebaseRemoteConfig.instance.getBool('use_hybrid_sync');
  }
}
```

#### 2.4 Update Orders Page

**Create a router that switches between implementations:**

```dart
// lib/features/orders/presentation/pages/orders_page_router.dart
import '../../../../core/config/feature_flags.dart';
import 'orders_page.dart';
import 'orders_page_hybrid.dart';

class OrdersPageRouter extends StatelessWidget {
  const OrdersPageRouter({super.key});

  @override
  Widget build(BuildContext context) {
    if (FeatureFlags.useHybridSync) {
      return OrdersPageHybrid();
    } else {
      return OrdersPage(); // Current implementation
    }
  }
}
```

**Update navigation to use router:**

```dart
// Replace direct navigation to OrdersPage
Navigator.push(context, MaterialPageRoute(
  builder: (context) => OrdersPageRouter(),
));
```

### Phase 3: Testing and Validation (3-4 hours)

#### 3.1 Unit Testing

**Create test file: `test/sync/hybrid_sync_manager_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:your_app/core/sync/hybrid_sync_manager.dart';

void main() {
  group('HybridSyncManager Tests', () {
    late HybridSyncManager syncManager;

    setUp(() async {
      syncManager = HybridSyncManager();
      // Mock or use test database
    });

    test('should initialize successfully', () async {
      await syncManager.initialize();
      expect(syncManager.isInitialized, isTrue);
    });

    test('should handle item completion toggle', () async {
      // Test optimistic updates and sync
      final events = <SyncEvent>[];
      syncManager.syncEvents.listen(events.add);

      await syncManager.toggleItemCompletion(
        orderId: 'test-order',
        itemId: 'test-item',
        isCompleted: true,
      );

      // Verify event sequence
      expect(events.length, greaterThanOrEqualTo(1));
      expect(events.first.type, SyncEventType.itemCompletionToggled);
    });

    tearDown(() {
      syncManager.dispose();
    });
  });
}
```

**Run tests:**
```bash
flutter test test/sync/hybrid_sync_manager_test.dart
```

#### 3.2 Integration Testing

**Single Device Testing:**

1. **Launch app with hybrid sync enabled**
   ```bash
   flutter run --debug
   ```

2. **Test basic functionality:**
   - [ ] Orders load correctly
   - [ ] Can mark items as complete
   - [ ] UI shows "syncing..." briefly
   - [ ] UI updates to confirmed state
   - [ ] Database reflects changes

3. **Test error scenarios:**
   - [ ] Disable network → make changes → enable network
   - [ ] Force app crash during sync
   - [ ] Test with invalid data

**Multi-Device Testing:**

1. **Setup two devices/browsers:**
   - Device A: Phone/tablet with app
   - Device B: Browser with same app

2. **Test sync scenarios:**
   - [ ] Mark item complete on Device A
   - [ ] Within 5 seconds, see change on Device B
   - [ ] Make conflicting changes on both devices
   - [ ] Verify server state wins

3. **Performance testing:**
   - [ ] Monitor network requests (should be minimal)
   - [ ] Check battery usage during long sessions
   - [ ] Verify polling stops when app is backgrounded

#### 3.3 Load Testing

**Database Performance:**

```sql
-- Test with multiple concurrent sync checks
SELECT pg_stat_activity WHERE query LIKE '%rpc_get_sync_metadata%';

-- Monitor trigger performance
SELECT schemaname, tablename, attname, n_distinct, correlation
FROM pg_stats WHERE tablename IN ('orders', 'order_items');
```

**Network Performance:**

```bash
# Monitor network requests
# In Flutter Inspector or browser dev tools
# Should see minimal requests compared to WebSocket version
```

### Phase 4: Gradual Rollout (1-2 days)

#### 4.1 A/B Testing Setup

**Using Firebase Remote Config:**

```dart
class FeatureFlags {
  static Future<void> initialize() async {
    await FirebaseRemoteConfig.instance.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: Duration(seconds: 10),
        minimumFetchInterval: Duration(hours: 1),
      ),
    );

    await FirebaseRemoteConfig.instance.setDefaults({
      'use_hybrid_sync': false,
      'hybrid_sync_poll_interval': 5,
    });

    await FirebaseRemoteConfig.instance.fetchAndActivate();
  }

  static bool get useHybridSync {
    return FirebaseRemoteConfig.instance.getBool('use_hybrid_sync');
  }

  static int get pollInterval {
    return FirebaseRemoteConfig.instance.getInt('hybrid_sync_poll_interval');
  }
}
```

#### 4.2 Monitoring Setup

**Add telemetry to track migration:**

```dart
class SyncMigrationTelemetry {
  static void trackSyncSystemUsed(String system) {
    FirebaseAnalytics.instance.logEvent(
      name: 'sync_system_used',
      parameters: {'system': system}, // 'hybrid' or 'cursor'
    );
  }

  static void trackSyncError(String system, String error) {
    FirebaseAnalytics.instance.logEvent(
      name: 'sync_error',
      parameters: {
        'system': system,
        'error': error,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  static void trackSyncPerformance(String operation, int durationMs) {
    FirebaseAnalytics.instance.logEvent(
      name: 'sync_performance',
      parameters: {
        'operation': operation,
        'duration_ms': durationMs,
      },
    );
  }
}
```

#### 4.3 Rollout Schedule

**Week 1: Internal Testing (0% users)**
- Enable for development team only
- Monitor error rates and performance
- Fix any critical issues

**Week 2: Beta Testing (10% users)**
```dart
static bool get useHybridSync {
  // Gradual rollout to 10% of users
  final userId = getCurrentUserId();
  final userHash = userId.hashCode.abs();
  return (userHash % 100) < 10;
}
```

**Week 3: Expanded Testing (50% users)**
```dart
return (userHash % 100) < 50;
```

**Week 4: Full Rollout (100% users)**
```dart
return true; // Or use remote config for instant rollback
```

### Phase 5: Cleanup and Optimization (1 day)

#### 5.1 Remove Old Code

**After successful migration:**

```bash
# Backup old files
mkdir -p backup/cursor_sync
cp lib/core/sync/cursor_sync_manager.dart backup/cursor_sync/
cp lib/features/orders/presentation/pages/orders_page.dart backup/cursor_sync/

# Remove old implementations
# rm lib/core/sync/cursor_sync_manager.dart  # Keep as backup initially
```

#### 5.2 Performance Optimization

**Database optimization:**

```sql
-- Analyze query performance
EXPLAIN ANALYZE SELECT * FROM sync_metadata WHERE key = 'orders_last_updated';

-- Add additional indexes if needed
CREATE INDEX CONCURRENTLY idx_orders_updated_at_id ON orders(updated_at, id);
```

**App optimization:**

```dart
// Fine-tune polling intervals based on usage patterns
class AdaptiveSyncManager extends HybridSyncManager {
  @override
  Duration _getCurrentPollInterval() {
    final hour = DateTime.now().hour;

    // Slower polling during off-hours
    if (hour < 6 || hour > 22) {
      return Duration(seconds: 15);
    }

    // Faster during peak hours
    return Duration(seconds: 3);
  }
}
```

## Rollback Plan

If issues arise during migration, follow this rollback procedure:

### Immediate Rollback (< 5 minutes)

**Remote Config Rollback:**
```dart
// Set remote config flag to false
await FirebaseRemoteConfig.instance.setDefaults({
  'use_hybrid_sync': false,
});
```

**Code Rollback:**
```dart
class FeatureFlags {
  static bool get useHybridSync {
    return false; // Immediate rollback
  }
}
```

### Database Rollback (if needed)

**Remove triggers (only if causing issues):**
```sql
-- Only run if database triggers are causing problems
DROP TRIGGER IF EXISTS trigger_orders_sync ON orders;
DROP TRIGGER IF EXISTS trigger_order_items_sync ON order_items;
DROP FUNCTION IF EXISTS update_orders_sync_timestamp();

-- Keep sync_metadata table for future attempts
-- DROP TABLE sync_metadata; -- Only if absolutely necessary
```

## Post-Migration Validation

### Success Criteria

- [ ] **Functionality**: All order operations work correctly
- [ ] **Performance**: Page load times under 2 seconds
- [ ] **Sync Speed**: Cross-device sync within 5 seconds
- [ ] **Error Rate**: < 1% sync failures
- [ ] **User Experience**: No user complaints about responsiveness

### Monitoring Checklist

- [ ] **Database Load**: Query frequency and performance
- [ ] **Network Usage**: Reduced compared to WebSocket version
- [ ] **Error Rates**: Sync failures and timeouts
- [ ] **User Metrics**: Session duration and engagement
- [ ] **Device Performance**: Memory and battery usage

### Long-term Monitoring

```dart
// Add to app initialization
class SyncHealthMonitor {
  static void startMonitoring() {
    Timer.periodic(Duration(minutes: 5), (_) {
      final status = HybridSyncManager().getSyncStatus();

      if (!status['isInitialized'] || status['lastKnownVersion'] == null) {
        // Alert: Sync system unhealthy
        reportSyncIssue('Sync system not functioning properly');
      }

      if (status['pollInterval'] > 30) {
        // Alert: Polling too slow
        reportSyncIssue('Polling interval too slow: ${status['pollInterval']}s');
      }
    });
  }
}
```

## Troubleshooting Common Issues

### Issue 1: Sync Not Working

**Symptoms**: Changes not appearing on other devices

**Diagnosis**:
```dart
final status = HybridSyncManager().getSyncStatus();
print('Sync Status: $status');
```

**Solutions**:
1. Check database triggers are installed
2. Verify network connectivity
3. Force refresh: `HybridSyncManager().forceRefresh()`

### Issue 2: Performance Degradation

**Symptoms**: App feels slower than before

**Solutions**:
1. Adjust polling interval: Increase from 5s to 10s
2. Optimize database queries
3. Check for memory leaks in event listeners

### Issue 3: High Network Usage

**Symptoms**: Increased data usage complaints

**Solutions**:
1. Implement smart polling (longer intervals when idle)
2. Add network condition detection
3. Batch multiple operations

## Success Validation

After migration, you should observe:

✅ **Simplified Codebase**: 80% reduction in sync-related code complexity
✅ **Reliable Sync**: Consistent 5-second cross-device synchronization
✅ **Better Performance**: Reduced memory usage and network overhead
✅ **Easier Debugging**: Clear event flow and error handling
✅ **Maintainable Code**: Simple, well-documented sync logic

## Next Steps

1. **Monitor for 2 weeks** - Watch for any issues or edge cases
2. **Collect User Feedback** - Ask users about responsiveness
3. **Optimize Performance** - Fine-tune based on usage patterns
4. **Plan Enhancements** - Consider offline support, batch operations
5. **Documentation** - Update team knowledge and onboarding docs

## Support

For migration issues:

1. Check [Troubleshooting Guide](HYBRID_SYNC_SYSTEM.md#troubleshooting)
2. Review migration logs and sync status
3. Test with minimal reproduction case
4. Document issue with sync status and logs

Remember: **Gradual migration with careful monitoring** is key to success!