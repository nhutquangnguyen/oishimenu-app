# OishiMenu Flutter App - Quick Reference Guide

## Project Structure Map

```
lib/
├── main.dart                          # App entry point with Hive & Riverpod setup
├── models/                            # Data models (immutable)
│   ├── menu_item.dart                 # MenuItem, MenuCategory, MenuSize, Recipe
│   ├── menu_options.dart              # OptionGroup, MenuOption, Relationships
│   ├── user.dart                      # AppUser model
│   └── order.dart                     # Order models and enums
├── services/                          # Business logic layer
│   ├── database_helper.dart           # SQLite singleton (version 3)
│   ├── menu_service.dart              # Menu & category CRUD
│   ├── menu_option_service.dart       # Option group CRUD + relationships
│   ├── auth_service.dart              # Authentication
│   └── order_service.dart             # Order management
├── core/                              # Core app infrastructure
│   ├── router/
│   │   └── app_router.dart            # GoRouter with auth guard
│   ├── config/
│   │   └── app_theme.dart             # Material3 theme (light & dark)
│   ├── constants/
│   │   └── app_constants.dart         # App-wide constants
│   ├── widgets/
│   │   └── main_layout.dart           # Main app layout with navigation
│   └── utils/                         # Utilities (empty, ready for expansion)
├── providers/                         # Top-level Riverpod providers (minimal)
└── features/                          # Feature modules (modular architecture)
    ├── auth/                          # Authentication feature
    │   ├── providers/
    │   │   └── auth_provider.dart     # Auth-related Riverpod providers
    │   ├── presentation/
    │   │   ├── pages/
    │   │   │   ├── login_page.dart
    │   │   │   └── signup_page.dart
    │   │   └── widgets/
    │   │       ├── auth_text_field.dart
    │   │       ├── auth_button.dart
    │   │       └── social_auth_button.dart
    │   └── services/
    │       └── auth_service.dart
    ├── menu/                          # Menu management feature
    │   ├── presentation/
    │   │   ├── pages/
    │   │   │   └── menu_page.dart
    │   │   └── widgets/
    │   │       └── menu_item_card.dart
    │   └── services/
    │       └── menu_service.dart
    ├── pos/                           # Point of Sale feature
    ├── orders/                        # Orders feature
    ├── dashboard/                     # Dashboard feature
    ├── inventory/                     # Inventory feature
    ├── employees/                     # Employees feature
    ├── feedback/                      # Feedback feature
    └── analytics/                     # Analytics feature
```

---

## Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **UI Framework** | Flutter | Cross-platform mobile/web app |
| **Design System** | Material3 | Modern Material Design |
| **State Management** | Riverpod 2.4.9 | Reactive state management |
| **Navigation** | GoRouter 12.1.3 | Type-safe routing |
| **Database** | SQLite (sqflite 2.4.2) | Local persistence |
| **Auth State** | Hive 2.2.3 | Fast local KV storage |
| **Localization** | easy_localization 3.0.3 | Multi-language support |
| **Utilities** | shared_preferences, intl, uuid | Common utilities |

---

## Database Schema (Option Groups Focus)

### Tables
```
menu_options
├── id (PK)
├── name
├── price
├── description
├── category
├── is_available
├── created_at
└── updated_at

option_groups
├── id (PK)
├── name
├── description
├── min_selection
├── max_selection
├── is_required
├── display_order
├── is_active
├── created_at
└── updated_at

option_group_options (many-to-many)
├── id (PK)
├── option_group_id (FK)
├── option_id (FK)
├── display_order
└── created_at

menu_item_option_groups (many-to-many)
├── id (PK)
├── menu_item_id (FK)
├── option_group_id (FK)
├── is_required
├── display_order
└── created_at
```

---

## Key Services & Methods

### MenuOptionService
```dart
// Options
getAllMenuOptions()
getMenuOptionsByCategory(String category)
createMenuOption(MenuOption option)
updateMenuOption(MenuOption option)
deleteMenuOption(String optionId)

// Groups
getAllOptionGroups()
getOptionGroupsForMenuItem(String menuItemId)
getOptionsForGroup(String optionGroupId)
createOptionGroup(OptionGroup optionGroup)
updateOptionGroup(OptionGroup optionGroup)

// Relationships
connectMenuItemToOptionGroup(menuItemId, groupId, {isRequired, displayOrder})
disconnectMenuItemFromOptionGroup(menuItemId, groupId)
connectOptionToGroup(optionId, groupId, {displayOrder})
disconnectOptionFromGroup(optionId, groupId)
getMenuItemsUsingOptionGroup(groupId)
connectOptionGroupToMenuItems(groupId, menuItemIds)
```

### MenuService
```dart
getCategories()
getCategoryById(String id)
addCategory(MenuCategory category)
updateCategory(MenuCategory category)
deleteCategory(String id)

getMenuItems({String? categoryId})
getMenuItemById(String id)
addMenuItem(MenuItem item, String categoryId)
updateMenuItem(MenuItem item, String categoryId)
deleteMenuItem(String id)

searchMenuItems(String query)
```

---

## Riverpod Provider Patterns

### Pattern 1: Service Provider (Dependency)
```dart
final menuOptionServiceProvider = Provider<MenuOptionService>((ref) {
  return MenuOptionService();
});
```

### Pattern 2: Future Data Provider
```dart
final optionGroupsProvider = FutureProvider<List<OptionGroup>>((ref) async {
  final service = ref.watch(menuOptionServiceProvider);
  return service.getAllOptionGroups();
});
```

### Pattern 3: Stream Provider (Real-time)
```dart
final authStateProvider = StreamProvider<AppUser?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});
```

### Pattern 4: Computed Provider
```dart
final isAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null;
});
```

### Pattern 5: State Provider (Mutable)
```dart
final selectedOptionGroupProvider = StateProvider<String?>((ref) => null);
```

---

## Navigation

### Routes
```
/login                    # Public
/signup                   # Public
/dashboard                # Protected (MainLayout)
/menu                     # Protected (MainLayout)
/orders                   # Protected (MainLayout)
/pos                      # Protected (MainLayout)
/inventory                # Protected (MainLayout)
/employees                # Protected (MainLayout)
/feedback                 # Protected (MainLayout)
/analytics                # Protected (MainLayout)
```

### Usage
```dart
// Direct navigation
context.go('/menu');

// Via provider
context.go(context.read(appRouterProvider).location);

// Extension methods
context.read(appRouterProvider).goToMenu();
```

---

## UI Component Patterns

### Widget Types
- **StatelessWidget**: Pure UI, no state
- **StatefulWidget**: Local mutable state
- **ConsumerWidget**: Access to Riverpod providers
- **ConsumerStatefulWidget**: Both local state and Riverpod

### Callback Pattern (Preferred)
```dart
class OptionGroupCard extends StatelessWidget {
  final OptionGroup optionGroup;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  
  // Parent handles navigation/logic
  // Widget is pure presentation
}
```

### Theme Usage
```dart
Text(
  'Price: ₫${item.price}',
  style: Theme.of(context).textTheme.titleMedium?.copyWith(
    color: Theme.of(context).colorScheme.primary,
  ),
)
```

---

## Common Code Patterns

### Model Creation (fromMap)
```dart
factory OptionGroup.fromMap(Map<String, dynamic> map) {
  return OptionGroup(
    id: map['id']?.toString() ?? '',
    name: map['name'] ?? '',
    minSelection: map['min_selection'] ?? 0,
    maxSelection: map['max_selection'] ?? 1,
    isRequired: (map['is_required'] ?? 0) == 1,
    displayOrder: map['display_order'] ?? 0,
    isActive: (map['is_active'] ?? 1) == 1,
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] ?? 0),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] ?? 0),
  );
}
```

### Model Serialization (toMap)
```dart
Map<String, dynamic> toMap() {
  return {
    'id': id.isEmpty ? null : int.tryParse(id),
    'name': name,
    'min_selection': minSelection,
    'max_selection': maxSelection,
    'is_required': isRequired ? 1 : 0,
    'display_order': displayOrder,
    'is_active': isActive ? 1 : 0,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };
}
```

### Model Updates (copyWith)
```dart
OptionGroup updatedGroup = optionGroup.copyWith(
  name: 'New Size Group',
  displayOrder: 2,
  isActive: true,
);
```

### Service CRUD Pattern
```dart
// Create
Future<String?> createOptionGroup(OptionGroup optionGroup) async {
  try {
    final db = await _databaseHelper.database;
    final id = await db.insert('option_groups', optionGroup.toMap());
    return id.toString();
  } catch (e) {
    print('Error creating option group: $e');
    return null;
  }
}

// Read
Future<List<OptionGroup>> getAllOptionGroups() async {
  try {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('option_groups');
    return maps.map((m) => OptionGroup.fromMap(m)).toList();
  } catch (e) {
    print('Error fetching option groups: $e');
    return [];
  }
}

// Update
Future<bool> updateOptionGroup(OptionGroup optionGroup) async {
  try {
    final db = await _databaseHelper.database;
    final rowsAffected = await db.update(
      'option_groups',
      optionGroup.toMap(),
      where: 'id = ?',
      whereArgs: [int.tryParse(optionGroup.id) ?? 0],
    );
    return rowsAffected > 0;
  } catch (e) {
    print('Error updating option group: $e');
    return false;
  }
}
```

### Database Query with Joins
```dart
Future<List<OptionGroup>> getOptionGroupsForMenuItem(String menuItemId) async {
  try {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT og.* FROM option_groups og
      INNER JOIN menu_item_option_groups miog ON og.id = miog.option_group_id
      WHERE miog.menu_item_id = ? AND og.is_active = 1
      ORDER BY miog.display_order ASC, og.display_order ASC
    ''', [int.tryParse(menuItemId) ?? 0]);

    List<OptionGroup> groups = [];
    for (final map in maps) {
      final group = OptionGroup.fromMap(map);
      final options = await getOptionsForGroup(group.id);
      groups.add(group.copyWith(options: options));
    }
    return groups;
  } catch (e) {
    print('Error fetching option groups for menu item: $e');
    return [];
  }
}
```

---

## Creating a New Feature (Example: Option Groups Management)

### Step 1: Create Feature Folder Structure
```bash
mkdir -p lib/features/option_groups/{providers,presentation/{pages,widgets}}
```

### Step 2: Create Riverpod Providers
**File**: `lib/features/option_groups/providers/option_group_provider.dart`
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/menu_option_service.dart';
import '../../../models/menu_options.dart';

final menuOptionServiceProvider = Provider<MenuOptionService>((ref) {
  return MenuOptionService();
});

final optionGroupsProvider = FutureProvider<List<OptionGroup>>((ref) async {
  final service = ref.watch(menuOptionServiceProvider);
  return service.getAllOptionGroups();
});

final selectedOptionGroupProvider = StateProvider<String?>((ref) => null);
```

### Step 3: Create Main Page
**File**: `lib/features/option_groups/presentation/pages/option_groups_page.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/option_group_provider.dart';
import '../widgets/option_group_card.dart';

class OptionGroupsPage extends ConsumerWidget {
  const OptionGroupsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optionGroups = ref.watch(optionGroupsProvider);

    return Scaffold(
      body: optionGroups.when(
        data: (groups) => ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) => OptionGroupCard(
            optionGroup: groups[index],
          ),
        ),
        loading: () => Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
```

### Step 4: Create Reusable Widget
**File**: `lib/features/option_groups/presentation/widgets/option_group_card.dart`
```dart
import 'package:flutter/material.dart';
import '../../../../models/menu_options.dart';

class OptionGroupCard extends StatelessWidget {
  final OptionGroup optionGroup;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const OptionGroupCard({
    super.key,
    required this.optionGroup,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(optionGroup.name),
        subtitle: Text(
          'Options: ${optionGroup.options.length} | '
          'Min: ${optionGroup.minSelection} Max: ${optionGroup.maxSelection}'
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: Icon(Icons.edit), onPressed: onEdit),
            IconButton(icon: Icon(Icons.delete), onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}
```

### Step 5: Add Route
**File**: `/lib/core/router/app_router.dart` (Update routes section)
```dart
GoRoute(
  path: '/option-groups',
  builder: (context, state) => const OptionGroupsPage(),
),
```

### Step 6: Add Navigation Item
**File**: `/lib/core/widgets/main_layout.dart` (Update secondary navigation)
```dart
MoreNavigationItem(
  icon: Icons.tune_outlined,
  label: 'Option Groups',
  route: '/option-groups',
  subtitle: 'Manage sizes, toppings, etc.',
),
```

### Step 7: Add Localization
**Files**: `/assets/translations/*.json`
```json
{
  "option_groups": "Option Groups",
  "manage_option_groups": "Manage Option Groups",
  "create_option_group": "Create Option Group",
  "edit_option_group": "Edit Option Group",
  "delete_option_group": "Delete Option Group"
}
```

---

## Default Credentials

```
Email: admin@oishimenu.com
Password: admin123
Role: admin
```

---

## Best Practices

1. **Always use null safety** (`??`, `?.`)
2. **Type annotations** on all public methods
3. **Immutable models** with `copyWith()` for updates
4. **Try-catch** in all service methods with logging
5. **Callbacks** for user actions in widgets (avoid direct nav)
6. **Theme.of(context)** for all styling (never hardcode colors)
7. **Provider composition** for derived state
8. **SQL with parameters** to prevent injection
9. **Transactions** for bulk operations
10. **Clear naming** (snake_case DB, camelCase Dart, PascalCase classes)

---

## Troubleshooting

### Issue: Provider not updating
**Solution**: Use `ref.watch()` not `ref.read()` for reactive updates

### Issue: Database locked
**Solution**: Ensure all database calls use `await` and are properly closed

### Issue: Navigation loop
**Solution**: Check redirect logic in `app_router.dart`, ensure auth state is correct

### Issue: Theme not applying
**Solution**: Verify widget uses `Theme.of(context)` and rebuilds when theme changes

---

## Next Steps for Option Groups Feature

1. Create Riverpod providers for option group state management
2. Build UI for creating/editing option groups
3. Build UI for managing options within groups
4. Integrate option groups into menu item editing
5. Display option groups in POS during order creation
6. Handle option group selection validation (min/max)
7. Calculate price adjustments for selected options
8. Display selected options in order summary

