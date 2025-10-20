# OishiMenu Flutter App - Codebase Architecture Analysis

## Executive Summary

The OishiMenu Flutter app is a comprehensive Vietnamese restaurant POS/management system built with modern Flutter architecture patterns. It uses Riverpod for state management, SQLite for local persistence, and follows a feature-based modular structure with clear separation of concerns.

---

## 1. DATA MODELS ORGANIZATION

### Location: `/lib/models/`

#### Core Models:
1. **menu_item.dart**
   - `MenuItem`: Main menu item model with pricing, availability, and metadata
   - `MenuCategory`: Category grouping for menu items
   - `MenuSize`: Size variations for menu items
   - `Recipe`: Recipe information with ingredients

2. **menu_options.dart** (NEW - Core to Option Groups feature)
   - `MenuOption`: Individual option/choice (e.g., "Medium", "Less Sugar", "Extra Cheese")
   - `OptionGroup`: Collection of related options (e.g., "Size", "Sweetness Level", "Toppings")
   - `MenuItemOptionGroup`: Junction table for MenuItem-to-OptionGroup relationship
   - `OptionGroupOption`: Junction table for OptionGroup-to-MenuOption relationship
   - `SelectedOption`: Represents a user's selected option during order creation

3. **user.dart**
   - `AppUser`: Authentication and user profile model
   - Supports role-based access (admin, manager, staff)

4. **order.dart**
   - Enums: `OrderStatus`, `OrderType`, `PaymentMethod`
   - Order models with full transaction details

### Model Design Patterns:
- **fromMap()** factory constructors for database deserialization
- **toMap()** methods for database serialization
- **copyWith()** for immutable-style updates
- Proper type conversions (String IDs, timestamp handling)
- SQLite-compatible field naming (snake_case)

---

## 2. DATABASE & STORAGE ARCHITECTURE

### Primary Storage: SQLite
**Location**: `/lib/services/database_helper.dart`

#### Key Tables (Relevant to Option Groups):
```sql
-- Menu Options (individual choices)
CREATE TABLE menu_options (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  price REAL NOT NULL DEFAULT 0,
  description TEXT,
  category TEXT,
  is_available INTEGER DEFAULT 1,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)

-- Option Groups (groupings like Size, Sweetness, etc.)
CREATE TABLE option_groups (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  description TEXT,
  min_selection INTEGER DEFAULT 0,
  max_selection INTEGER DEFAULT 1,
  is_required INTEGER DEFAULT 0,
  display_order INTEGER DEFAULT 0,
  is_active INTEGER DEFAULT 1,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)

-- Many-to-many: OptionGroup to MenuOption
CREATE TABLE option_group_options (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  option_group_id INTEGER NOT NULL,
  option_id INTEGER NOT NULL,
  display_order INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (option_group_id) REFERENCES option_groups (id) ON DELETE CASCADE,
  FOREIGN KEY (option_id) REFERENCES menu_options (id) ON DELETE CASCADE
)

-- Many-to-many: MenuItem to OptionGroup
CREATE TABLE menu_item_option_groups (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  menu_item_id INTEGER NOT NULL,
  option_group_id INTEGER NOT NULL,
  is_required INTEGER DEFAULT 0,
  display_order INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (menu_item_id) REFERENCES menu_items (id) ON DELETE CASCADE,
  FOREIGN KEY (option_group_id) REFERENCES option_groups (id) ON DELETE CASCADE
)
```

#### Database Singleton Pattern:
- Single `DatabaseHelper()` instance across app
- Lazy initialization with null-coalescing (`??=`)
- Automatic migration on version upgrade
- Transaction support for bulk operations

#### Secondary Storage: 
- **Hive**: Authentication state persistence
- **SharedPreferences**: Locale and app settings

---

## 3. SERVICE LAYER ORGANIZATION

### Location: `/lib/services/`

#### MenuOptionService
**File**: `/lib/services/menu_option_service.dart`

Comprehensive CRUD and relationship management for options and groups:

**Menu Options CRUD:**
- `getAllMenuOptions()` - Get all available options
- `getMenuOptionsByCategory(String category)` - Filter by category
- `createMenuOption(MenuOption option)` - Create new option
- `updateMenuOption(MenuOption option)` - Update existing option
- `deleteMenuOption(String optionId)` - Soft delete option

**Option Groups CRUD:**
- `getAllOptionGroups()` - Get all active groups with options
- `getOptionGroupsForMenuItem(String menuItemId)` - Get groups for specific item
- `getOptionsForGroup(String optionGroupId)` - Get options in a group
- `createOptionGroup(OptionGroup optionGroup)` - Create new group
- `updateOptionGroup(OptionGroup optionGroup)` - Update existing group

**Relationship Management:**
- `connectMenuItemToOptionGroup(...)` - Link item to group
- `disconnectMenuItemFromOptionGroup(...)` - Remove link
- `connectOptionToGroup(...)` - Link option to group
- `disconnectOptionFromGroup(...)` - Remove link
- `getMenuItemsUsingOptionGroup(...)` - Find items using group
- `connectOptionGroupToMenuItems(...)` - Bulk link with transaction

#### MenuService
**File**: `/lib/services/menu_service.dart`

Menu and category management following same patterns.

#### Common Service Patterns:
1. **Dependency Injection**: Services instantiate `DatabaseHelper()` singleton internally
2. **Error Handling**: Try-catch blocks with print logging
3. **Type Safety**: Strong typing for IDs, proper casting
4. **Null Safety**: Null-coalescing (`??`) for optional fields
5. **Return Types**:
   - `Future<T>` for data retrieval
   - `Future<bool>` for operations (success/failure)
   - `Future<String?>` for ID generation

---

## 4. UI COMPONENTS & SCREENS STRUCTURE

### Location: `/lib/features/` (Modular Feature Structure)

#### Feature Folder Structure:
```
features/
├── auth/
│   ├── presentation/
│   │   ├── pages/
│   │   └── widgets/
│   ├── providers/
│   └── services/
│
├── menu/
│   ├── presentation/
│   │   ├── pages/
│   │   └── widgets/
│   └── services/
│
├── orders/
├── pos/
├── dashboard/
├── inventory/
├── employees/
├── feedback/
└── analytics/
```

#### Key UI Patterns:
- **Card-based**: Uses Material3 `Card` with custom styling
- **Callback Architecture**: Passes callbacks for actions (edit, delete, toggle)
- **Theme Integration**: Uses `Theme.of(context)` for consistent styling
- **Responsive**: Uses `Expanded`, `Spacer`, and flexible layouts
- **Accessibility**: Tooltips on icon buttons

#### MenuPage Example Pattern:
- **StatefulWidget** for local state management
- **TabController** for tab switching
- **Two-level load**: Sync UI immediately, async data loading
- **Search/Filter**: Real-time filtering with setState
- **Tab Pattern**: Shows both menu items and option groups management

---

## 5. STATE MANAGEMENT - RIVERPOD

### Location: `/lib/features/auth/providers/auth_provider.dart`

#### Provider Types Used:

1. **Service Provider** (Dependency):
   ```dart
   final authServiceProvider = Provider<AuthService>((ref) {
     throw UnimplementedError('Override in main.dart');
   });
   ```
   - Overridden in `main.dart` with actual instance

2. **Stream Provider** (Async Data):
   ```dart
   final authStateProvider = StreamProvider<AppUser?>((ref) {
     final authService = ref.watch(authServiceProvider);
     return authService.authStateChanges;
   });
   ```

3. **Computed Providers** (Derived State):
   ```dart
   final currentUserProvider = Provider<AppUser?>((ref) {
     final authState = ref.watch(authStateProvider);
     return authState.when(
       data: (user) => user,
       loading: () => null,
       error: (_, __) => null,
     );
   });
   ```

4. **State Providers** (Mutable State):
   ```dart
   final authLoadingProvider = StateProvider<bool>((ref) => false);
   ```

#### Provider Patterns for New Features:
- **Read-only data**: Use `FutureProvider` or `Provider`
- **Mutable state**: Use `StateProvider`
- **Business logic**: Create `StateNotifier` classes
- **Side effects**: Use `ref.watch()` in widgets

---

## 6. ROUTING ARCHITECTURE

### Location: `/lib/core/router/app_router.dart`

#### Go Router Setup:
- `Provider<GoRouter>` watches auth state
- Automatic redirect to `/login` if not authenticated
- Protected routes wrapped in `ShellRoute` for MainLayout
- Extension methods for type-safe navigation

#### Route Structure:
- **Public**: `/login`, `/signup`
- **Protected**: `/dashboard`, `/menu`, `/orders`, `/pos`, `/inventory`, `/employees`, `/feedback`, `/analytics`

#### Navigation Extensions:
```dart
context.go('/menu');
ref.read(appRouterProvider).goToMenu();
```

---

## 7. LOCALIZATION/TRANSLATION

### Implementation: easy_localization Package

#### Translation Files:
**Location**: `/assets/translations/`
- `en.json` - English (US)
- `en-US.json` - English variant
- `vi.json` - Vietnamese

#### Usage Pattern (Ready to implement):
```dart
Text('menu'.tr());  // Translates to current locale
```

---

## 8. THEME SYSTEM

### Location: `/lib/core/config/app_theme.dart`

- **Material Design 3** compliance
- **Light and Dark themes** predefined
- **Color scheme**: Purple primary (#6d28d9), Indigo secondary
- **Comprehensive component theming**: AppBar, Card, Button, Input, etc.
- **Responsive typography**: Full TextTheme defined

---

## 9. ARCHITECTURE LAYERS

```
┌─────────────────────────────────────────────────────┐
│              PRESENTATION LAYER                      │
│  (Pages, Widgets, UI Components)                    │
│  - Material3 Design System                          │
└──────────────────┬──────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────┐
│           STATE MANAGEMENT LAYER                    │
│  (Riverpod Providers)                              │
│  - Provider, StateProvider, StreamProvider          │
└──────────────────┬──────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────┐
│            SERVICE LAYER                            │
│  (Business Logic)                                   │
│  - MenuService, MenuOptionService, AuthService      │
└──────────────────┬──────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────┐
│         PERSISTENCE LAYER                           │
│  - SQLite (Primary), Hive (Auth), SharedPreferences │
└─────────────────────────────────────────────────────┘
```

---

## 10. KEY FILES SUMMARY

| File | Purpose | Key Classes |
|------|---------|------------|
| `/lib/main.dart` | Entry point | OishiMenuApp |
| `/lib/models/menu_options.dart` | Option group models | MenuOption, OptionGroup, MenuItemOptionGroup, OptionGroupOption, SelectedOption |
| `/lib/services/menu_option_service.dart` | Option group CRUD | MenuOptionService |
| `/lib/core/router/app_router.dart` | Navigation | appRouterProvider |
| `/lib/core/config/app_theme.dart` | Theme | AppTheme |
| `/lib/features/auth/providers/auth_provider.dart` | Auth state | Auth providers |
| `/lib/core/widgets/main_layout.dart` | Main layout | MainLayout |

---

## 11. CONVENTIONS FOR NEW FEATURES

### When Adding Option Group UI Features:

1. **Create Providers** (Riverpod):
   ```
   /lib/features/option_groups/
   ├── providers/
   │   └── option_group_provider.dart
   ├── presentation/
   │   ├── pages/
   │   └── widgets/
   └── services/ (optional - use existing MenuOptionService)
   ```

2. **Provider Pattern**:
   - Service Provider → StreamProvider → Computed Providers
   - Watch dependencies explicitly
   - Use `ref.watch()` for reactive updates

3. **Widget Pattern**:
   - Use `ConsumerWidget` or `ConsumerStatefulWidget`
   - Pass callbacks instead of direct navigation
   - Use `Theme.of(context)` for styling

4. **Service Layer**:
   - Extend `MenuOptionService` (already comprehensive)
   - Follow try-catch error handling
   - Return `Future<T>` with appropriate types

5. **Code Style**:
   - **Snake_case** for database columns
   - **camelCase** for Dart variables/methods
   - **PascalCase** for class names
   - Null safety with `??` and `?.` operators
   - Explicit type annotations

---

## 12. DATABASE INITIALIZATION

### Default Setup:
- **Admin user**: `admin@oishimenu.com` / `admin123`
- **Sample categories**: Appetizers, Main Course, Desserts, Beverages, Vietnamese Specials
- **Version control**: Auto-migrations on app update
- **Schema**: Fully normalized with foreign keys and cascading deletes

---

## Conclusion

The OishiMenu Flutter app follows modern Flutter best practices with clear separation of concerns, reactive state management, and a modular feature structure. The option groups feature is fully modeled with database support. Next steps involve creating comprehensive UI for managing and visualizing option groups within the POS system.
