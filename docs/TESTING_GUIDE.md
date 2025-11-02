# Hybrid Sync Testing Guide

Comprehensive testing guide for the Hybrid Real-Time Sync System. This guide covers unit tests, integration tests, performance tests, and user acceptance testing.

## Table of Contents

- [Test Environment Setup](#test-environment-setup)
- [Unit Testing](#unit-testing)
- [Integration Testing](#integration-testing)
- [Performance Testing](#performance-testing)
- [User Acceptance Testing](#user-acceptance-testing)
- [Load Testing](#load-testing)
- [Error Scenario Testing](#error-scenario-testing)
- [Automated Testing](#automated-testing)

## Test Environment Setup

### Prerequisites

```bash
# Install testing dependencies
flutter pub get
dart pub global activate coverage

# Setup test database
cp .env.example .env.test
# Configure test database URL in .env.test
```

### Test Configuration

```dart
// test/test_config.dart
class TestConfig {
  static const String testDatabaseUrl = 'your-test-supabase-url';
  static const String testApiKey = 'your-test-api-key';

  static Future<void> setupTestEnvironment() async {
    // Initialize test database
    await Supabase.initialize(
      url: testDatabaseUrl,
      anonKey: testApiKey,
    );

    // Clean test data
    await _cleanTestData();
  }

  static Future<void> _cleanTestData() async {
    final client = Supabase.instance.client;
    await client.from('order_items').delete().neq('id', 'never-matches');
    await client.from('orders').delete().neq('id', 'never-matches');
    await client.from('sync_metadata').delete().neq('key', 'never-matches');
  }
}
```

## Unit Testing

### Test Structure

```dart
// test/sync/hybrid_sync_manager_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:your_app/core/sync/hybrid_sync_manager.dart';

void main() {
  group('HybridSyncManager', () {
    late HybridSyncManager syncManager;

    setUp(() async {
      await TestConfig.setupTestEnvironment();
      syncManager = HybridSyncManager();
    });

    tearDown(() {
      syncManager.dispose();
    });

    // Add tests here
  });
}
```

### Core Functionality Tests

```dart
test('should initialize successfully', () async {
  await syncManager.initialize();

  expect(syncManager.isInitialized, isTrue);
  expect(syncManager.isPolling, isTrue);
});

test('should handle item completion toggle', () async {
  await syncManager.initialize();

  final events = <SyncEvent>[];
  syncManager.syncEvents.listen(events.add);

  await syncManager.toggleItemCompletion(
    orderId: 'test-order-1',
    itemId: 'test-item-1',
    isCompleted: true,
  );

  // Wait for events
  await Future.delayed(Duration(milliseconds: 100));

  expect(events.length, greaterThanOrEqualTo(1));
  expect(events.first.type, SyncEventType.itemCompletionToggled);
  expect(events.first.isOptimistic, isTrue);
});

test('should detect version changes', () async {
  await syncManager.initialize();

  // Simulate server version change
  await _updateServerVersion();

  // Force sync check
  await syncManager.forceRefresh();

  final events = <SyncEvent>[];
  syncManager.syncEvents.listen(events.add);

  await Future.delayed(Duration(milliseconds: 500));

  final dataUpdatedEvents = events
      .where((e) => e.type == SyncEventType.dataUpdated)
      .toList();

  expect(dataUpdatedEvents.length, equals(1));
});

test('should handle sync errors gracefully', () async {
  await syncManager.initialize();

  final events = <SyncEvent>[];
  syncManager.syncEvents.listen(events.add);

  // Try to update non-existent item
  await syncManager.toggleItemCompletion(
    orderId: 'non-existent-order',
    itemId: 'non-existent-item',
    isCompleted: true,
  );

  await Future.delayed(Duration(seconds: 2));

  final errorEvents = events.where((e) => e.isError).toList();
  expect(errorEvents.length, greaterThan(0));
});

test('should manage polling lifecycle', () async {
  await syncManager.initialize();

  expect(syncManager.isPolling, isTrue);

  syncManager.stopPolling();
  expect(syncManager.isPolling, isFalse);

  syncManager.startPolling();
  expect(syncManager.isPolling, isTrue);
});

test('should handle app lifecycle changes', () async {
  await syncManager.initialize();

  // App goes to background
  syncManager.setAppForegroundState(false);
  final backgroundStatus = syncManager.getSyncStatus();
  expect(backgroundStatus['isAppInForeground'], isFalse);

  // App returns to foreground
  syncManager.setAppForegroundState(true);
  final foregroundStatus = syncManager.getSyncStatus();
  expect(foregroundStatus['isAppInForeground'], isTrue);
});
```

### Event System Tests

```dart
// test/sync/sync_events_test.dart
test('should create optimistic events correctly', () {
  final event = SyncEvent.itemCompletionToggled(
    orderId: 'order-1',
    itemId: 'item-1',
    isCompleted: true,
    isOptimistic: true,
  );

  expect(event.type, SyncEventType.itemCompletionToggled);
  expect(event.isOptimistic, isTrue);
  expect(event.data['orderId'], equals('order-1'));
  expect(event.data['isCompleted'], isTrue);
});

test('should create error events with proper metadata', () {
  final exception = Exception('Test error');
  final event = SyncEvent.error(
    message: 'Sync failed',
    errorCode: 'NETWORK_ERROR',
    exception: exception,
  );

  expect(event.isError, isTrue);
  expect(event.errorCode, equals('NETWORK_ERROR'));
  expect(event.metadata?['exception'], contains('Test error'));
});
```

### Model Tests

```dart
// test/models/order_test.dart
test('should handle sync fields correctly', () {
  final customer = Customer(
    id: '1',
    name: 'Test Customer',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final order = Order(
    id: '1',
    orderNumber: 'ORD-001',
    customer: customer,
    items: [],
    subtotal: 10.0,
    total: 10.0,
    orderType: OrderType.dineIn,
    status: OrderStatus.pending,
    paymentMethod: PaymentMethod.cash,
    paymentStatus: PaymentStatus.pending,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    isLocalPending: true,
    hasLocalChanges: false,
  );

  expect(order.isLocalPending, isTrue);
  expect(order.hasLocalChanges, isFalse);
  expect(order.syncError, isNull);

  final updatedOrder = order.copyWith(
    isLocalPending: false,
    syncError: 'Test error',
  );

  expect(updatedOrder.isLocalPending, isFalse);
  expect(updatedOrder.syncError, equals('Test error'));
});

test('should handle order item sync fields', () {
  final item = OrderItem(
    id: '1',
    menuItemId: '1',
    menuItemName: 'Test Item',
    basePrice: 5.0,
    quantity: 2,
    subtotal: 10.0,
    isCompleted: false,
    isLocalPending: true,
  );

  expect(item.isLocalPending, isTrue);
  expect(item.syncError, isNull);

  final syncedItem = item.copyWith(
    isCompleted: true,
    isLocalPending: false,
    completedAt: DateTime.now(),
  );

  expect(syncedItem.isCompleted, isTrue);
  expect(syncedItem.isLocalPending, isFalse);
  expect(syncedItem.completedAt, isNotNull);
});
```

## Integration Testing

### End-to-End Flow Tests

```dart
// test/integration/sync_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Sync Integration Tests', () {
    testWidgets('complete order item sync flow', (tester) async {
      // Launch app
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();

      // Navigate to orders page
      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();

      // Find first incomplete item
      final itemCheckbox = find.byType(Checkbox).first;
      await tester.tap(itemCheckbox);
      await tester.pump();

      // Verify optimistic update
      expect(find.text('Syncing...'), findsOneWidget);

      // Wait for sync completion
      await tester.pumpAndSettle(Duration(seconds: 3));

      // Verify completion
      expect(find.text('Syncing...'), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('order creation flow', (tester) async {
      // Navigate to POS
      await tester.tap(find.text('POS'));
      await tester.pumpAndSettle();

      // Add items to order
      await tester.tap(find.text('Test Menu Item'));
      await tester.pump();

      // Create order
      await tester.tap(find.text('Create Order'));
      await tester.pumpAndSettle();

      // Verify order appears in orders list
      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();

      expect(find.text('Test Menu Item'), findsOneWidget);
    });
  });
}
```

### Database Integration Tests

```dart
// test/integration/database_test.dart
test('should trigger sync metadata updates', () async {
  await TestConfig.setupTestEnvironment();

  // Get initial version
  final initialMetadata = await _getSyncMetadata();

  // Create test order
  final orderId = await _createTestOrder();

  // Check version updated
  final updatedMetadata = await _getSyncMetadata();
  expect(updatedMetadata.version, greaterThan(initialMetadata.version));

  // Update order item
  await _updateOrderItem(orderId);

  // Check version updated again
  final finalMetadata = await _getSyncMetadata();
  expect(finalMetadata.version, greaterThan(updatedMetadata.version));
});

test('should handle RPC functions correctly', () async {
  await TestConfig.setupTestEnvironment();

  final orderId = await _createTestOrder();
  final itemId = await _getFirstItemId(orderId);

  // Test item completion RPC
  final result = await Supabase.instance.client
      .rpc('rpc_update_order_item_completion', params: {
    'p_order_id': orderId,
    'p_item_id': itemId,
    'p_is_completed': true,
  });

  expect(result['success'], isTrue);
  expect(result['is_completed'], isTrue);
});
```

## Performance Testing

### Polling Performance Tests

```dart
// test/performance/polling_test.dart
test('should maintain acceptable polling frequency', () async {
  final syncManager = HybridSyncManager();
  await syncManager.initialize();

  final pollCounts = <DateTime>[];

  // Override polling check to count calls
  syncManager.syncEvents.listen((event) {
    if (event.type == SyncEventType.syncStarted) {
      pollCounts.add(DateTime.now());
    }
  });

  // Wait for multiple poll cycles
  await Future.delayed(Duration(seconds: 15));

  // Should have 3 polls (at 0s, 5s, 10s)
  expect(pollCounts.length, inInclusiveRange(2, 4));

  // Check intervals are roughly 5 seconds
  for (int i = 1; i < pollCounts.length; i++) {
    final interval = pollCounts[i].difference(pollCounts[i - 1]);
    expect(interval.inSeconds, inInclusiveRange(4, 6));
  }
});

test('should handle rapid user actions efficiently', () async {
  final syncManager = HybridSyncManager();
  await syncManager.initialize();

  final startTime = DateTime.now();

  // Simulate rapid button taps
  for (int i = 0; i < 5; i++) {
    syncManager.toggleItemCompletion(
      orderId: 'test-order',
      itemId: 'test-item-$i',
      isCompleted: true,
    );
    await Future.delayed(Duration(milliseconds: 100));
  }

  await Future.delayed(Duration(seconds: 2));

  final duration = DateTime.now().difference(startTime);
  expect(duration.inSeconds, lessThan(3));
});
```

### Memory Usage Tests

```dart
test('should not leak memory over time', () async {
  final syncManager = HybridSyncManager();
  await syncManager.initialize();

  // Baseline memory
  await _forceGarbageCollection();
  final baselineMemory = _getCurrentMemoryUsage();

  // Simulate extended usage
  for (int cycle = 0; cycle < 10; cycle++) {
    // Create events
    for (int i = 0; i < 100; i++) {
      syncManager.syncEvents.listen((_) {});
    }

    // Force cleanup
    await _forceGarbageCollection();
  }

  final finalMemory = _getCurrentMemoryUsage();
  final memoryIncrease = finalMemory - baselineMemory;

  // Memory should not increase significantly
  expect(memoryIncrease, lessThan(10 * 1024 * 1024)); // 10MB threshold
});
```

## User Acceptance Testing

### Test Scenarios

#### Scenario 1: Restaurant Staff Workflow

**Objective**: Verify typical restaurant operations work smoothly

**Steps**:
1. **Setup**: Open app on kitchen display and manager tablet
2. **New Order**: Create order on manager tablet
   - ✅ Order appears on kitchen display within 5 seconds
3. **Item Completion**: Mark items complete on kitchen display
   - ✅ Manager tablet shows completion within 5 seconds
   - ✅ UI shows "syncing..." briefly then confirms
4. **Order Status**: Change order status to "ready"
   - ✅ Both devices show updated status
5. **Error Handling**: Disconnect network on one device
   - ✅ Device shows appropriate error message
   - ✅ Changes sync when network restored

#### Scenario 2: Multi-Location Chain

**Objective**: Test sync across multiple restaurant locations

**Steps**:
1. **Setup**: Open app at 3 different locations
2. **Central Monitoring**: Manager views orders from all locations
3. **Local Updates**: Each location updates their orders
   - ✅ Central manager sees all updates within 5 seconds
   - ✅ Locations don't see each other's orders (proper filtering)

#### Scenario 3: High-Volume Testing

**Objective**: Verify performance during busy periods

**Steps**:
1. **Setup**: Simulate 20 concurrent orders
2. **Rapid Updates**: Mark items complete quickly across orders
   - ✅ UI remains responsive (< 100ms tap response)
   - ✅ All updates sync correctly
   - ✅ No stuck "syncing..." states

### Acceptance Criteria

| Criteria | Target | Test Method |
|----------|--------|-------------|
| **Sync Speed** | < 5 seconds | Multi-device testing |
| **UI Responsiveness** | < 100ms tap response | Performance monitoring |
| **Error Recovery** | < 30 seconds | Network simulation |
| **Battery Impact** | < 5% additional drain | Device monitoring |
| **Data Usage** | < 50% of WebSocket version | Network monitoring |
| **Reliability** | 99.9% uptime | Load testing |

## Load Testing

### Concurrent User Testing

```dart
// test/load/concurrent_users_test.dart
test('should handle 50 concurrent users', () async {
  final futures = <Future>[];

  for (int i = 0; i < 50; i++) {
    futures.add(_simulateUser(i));
  }

  final results = await Future.wait(futures);

  // All users should complete successfully
  final successCount = results.where((r) => r == true).length;
  expect(successCount, equals(50));
});

Future<bool> _simulateUser(int userId) async {
  try {
    final syncManager = HybridSyncManager();
    await syncManager.initialize();

    // Simulate user actions
    for (int i = 0; i < 10; i++) {
      await syncManager.toggleItemCompletion(
        orderId: 'user-$userId-order',
        itemId: 'user-$userId-item-$i',
        isCompleted: true,
      );

      await Future.delayed(Duration(milliseconds: 200));
    }

    return true;
  } catch (e) {
    print('User $userId failed: $e');
    return false;
  }
}
```

### Database Load Testing

```sql
-- test/load/database_load_test.sql
-- Test concurrent sync metadata updates
DO $$
DECLARE
    i INTEGER;
BEGIN
    -- Simulate 100 concurrent order updates
    FOR i IN 1..100 LOOP
        PERFORM pg_advisory_lock(12345);

        UPDATE sync_metadata
        SET last_updated = NOW(), version = version + 1
        WHERE key = 'orders_last_updated';

        PERFORM pg_advisory_unlock(12345);
    END LOOP;
END $$;

-- Verify final state
SELECT * FROM sync_metadata WHERE key = 'orders_last_updated';
```

## Error Scenario Testing

### Network Error Tests

```dart
test('should handle network disconnection gracefully', () async {
  final syncManager = HybridSyncManager();
  await syncManager.initialize();

  final events = <SyncEvent>[];
  syncManager.syncEvents.listen(events.add);

  // Simulate network disconnection
  await _simulateNetworkDisconnection();

  // Try to make changes
  await syncManager.toggleItemCompletion(
    orderId: 'test-order',
    itemId: 'test-item',
    isCompleted: true,
  );

  // Should get network error
  await Future.delayed(Duration(seconds: 2));

  final networkErrors = events
      .where((e) => e.type == SyncEventType.networkError)
      .toList();

  expect(networkErrors.length, greaterThan(0));

  // Restore network
  await _simulateNetworkReconnection();

  // Should recover automatically
  await Future.delayed(Duration(seconds: 5));

  final recoveryEvents = events
      .where((e) => e.type == SyncEventType.connectionRestored)
      .toList();

  expect(recoveryEvents.length, greaterThan(0));
});
```

### Database Error Tests

```dart
test('should handle database errors gracefully', () async {
  final syncManager = HybridSyncManager();
  await syncManager.initialize();

  // Simulate database constraint violation
  await expectLater(
    syncManager.toggleItemCompletion(
      orderId: 'invalid-order',
      itemId: 'invalid-item',
      isCompleted: true,
    ),
    throwsException,
  );

  // Sync manager should still be functional
  expect(syncManager.isInitialized, isTrue);
  expect(syncManager.isPolling, isTrue);
});
```

## Automated Testing

### Continuous Integration Setup

```yaml
# .github/workflows/test_sync.yml
name: Sync System Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:13
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
    - uses: actions/checkout@v2

    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.16.0'

    - name: Install dependencies
      run: flutter pub get

    - name: Setup test database
      run: |
        psql -h localhost -U postgres -c "CREATE DATABASE test_db;"
        psql -h localhost -U postgres -d test_db -f database/hybrid_sync_schema.sql

    - name: Run unit tests
      run: flutter test test/sync/

    - name: Run integration tests
      run: flutter test integration_test/

    - name: Generate coverage
      run: |
        flutter test --coverage
        lcov --remove coverage/lcov.info '**/*.g.dart' -o coverage/lcov_cleaned.info

    - name: Upload coverage
      uses: codecov/codecov-action@v2
      with:
        file: coverage/lcov_cleaned.info
```

### Test Utilities

```dart
// test/utils/test_helpers.dart
class TestHelpers {
  static Future<String> createTestOrder({
    String? customerId,
    List<OrderItem>? items,
  }) async {
    // Implementation
  }

  static Future<SyncMetadata> getSyncMetadata() async {
    // Implementation
  }

  static Future<void> updateServerVersion() async {
    // Implementation
  }

  static Future<void> simulateNetworkDelay(Duration delay) async {
    // Implementation
  }

  static Future<void> cleanTestDatabase() async {
    // Implementation
  }
}
```

## Test Reporting

### Coverage Requirements

- **Unit Tests**: > 90% code coverage
- **Integration Tests**: > 80% feature coverage
- **Performance Tests**: All critical paths tested

### Test Documentation

```dart
// test/test_reports.dart
class TestReporter {
  static void generateReport() {
    final report = TestReport()
      ..addSection('Unit Tests', _unitTestResults)
      ..addSection('Integration Tests', _integrationTestResults)
      ..addSection('Performance Tests', _performanceTestResults);

    report.saveToFile('test_results/sync_test_report.html');
  }
}
```

## Best Practices

### Test Organization

```
test/
├── sync/
│   ├── hybrid_sync_manager_test.dart
│   ├── sync_events_test.dart
│   └── sync_performance_test.dart
├── models/
│   └── order_test.dart
├── integration/
│   ├── sync_flow_test.dart
│   └── database_test.dart
├── load/
│   └── concurrent_users_test.dart
└── utils/
    └── test_helpers.dart
```

### Test Data Management

```dart
class TestDataManager {
  static const Map<String, dynamic> defaultOrder = {
    'id': 'test-order-1',
    'orderNumber': 'TEST-001',
    'customerId': 'test-customer-1',
    'status': 'PENDING',
    'total': 25.99,
  };

  static const Map<String, dynamic> defaultOrderItem = {
    'id': 'test-item-1',
    'menuItemName': 'Test Burger',
    'quantity': 1,
    'isCompleted': false,
  };
}
```

### Mock Services

```dart
// test/mocks/mock_supabase_service.dart
class MockSupabaseOrderService extends Mock implements SupabaseOrderService {
  @override
  Future<List<Order>> getOrders({int? limit}) async {
    return [
      Order.fromMap(TestDataManager.defaultOrder),
    ];
  }

  @override
  Future<String> createOrder(Order order) async {
    return 'mock-order-id';
  }
}
```

## Conclusion

This comprehensive testing guide ensures the Hybrid Sync System is thoroughly validated before production deployment. Follow all test categories to ensure reliability, performance, and user satisfaction.

### Test Checklist

- [ ] Unit tests pass (> 90% coverage)
- [ ] Integration tests pass
- [ ] Performance benchmarks met
- [ ] User acceptance criteria satisfied
- [ ] Load testing completed
- [ ] Error scenarios handled
- [ ] Automated tests integrated
- [ ] Documentation updated

Remember: **Testing is critical for sync systems** - reliability depends on thorough validation of all scenarios.