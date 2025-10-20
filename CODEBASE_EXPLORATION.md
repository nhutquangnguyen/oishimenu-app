# OishiMenu Flutter App - Codebase Exploration Report

## Overview

This document serves as the master index for the OishiMenu Flutter app codebase exploration. It contains comprehensive analysis of the app architecture, design patterns, and ready-to-use templates for extending the option groups feature.

**Last Updated:** October 20, 2025
**Explorer:** Claude Code
**App Version:** 1.0.0

---

## Documentation Files

This exploration includes three complementary documentation files:

### 1. **ARCHITECTURE_GUIDE.md** (Most Comprehensive)
- Deep dive into each architectural layer
- Database schema with SQL
- Service layer method documentation
- State management patterns
- UI component patterns
- Localization setup
- **Use this for:** Understanding the complete architecture and implementation details

### 2. **QUICK_REFERENCE.md** (Most Practical)
- Project structure map
- Technology stack table
- Database schema diagrams
- Service method quick lookup
- Riverpod provider patterns
- Complete feature creation example
- Code pattern templates
- **Use this for:** Quick lookups while coding, copy-paste templates

### 3. **CODEBASE_EXPLORATION.md** (This File)
- High-level summary
- Key findings
- Directory of all documentation
- Links to critical files
- Next steps roadmap

---

## Key Findings Summary

### Option Groups Feature Status

**Database:** READY
- 4 SQLite tables designed and implemented
- Automatic migrations from version 2 to 3
- Foreign keys with cascading deletes
- Display ordering for UI sorting

**Data Models:** READY
- MenuOption class (individual choice)
- OptionGroup class (collection of options)
- MenuItemOptionGroup junction table
- OptionGroupOption junction table
- SelectedOption (for order creation)

**Service Layer:** READY
- MenuOptionService with 15+ methods
- CRUD operations for options and groups
- Relationship management (connect/disconnect)
- Bulk operations with transactions
- Comprehensive error handling

**State Management:** PATTERN READY
- Riverpod examples from auth system
- Provider patterns ready to reuse
- Dependency injection structure established

**UI Infrastructure:** READY
- Material3 design system
- Theme system with light/dark support
- Navigation structure (GoRouter)
- Component patterns (Cards, Callbacks)
- Main layout with bottom navigation

**What's Missing:** UI Implementation
- No list/detail pages for option groups
- No create/edit forms
- No integration into menu item editing
- No integration into POS order creation

---

## Critical Files

### Data Layer
```
/lib/models/menu_options.dart          - All option group models
/lib/services/database_helper.dart     - SQLite setup and migration
/lib/services/menu_option_service.dart - Option group CRUD operations
```

### State Management
```
/lib/features/auth/providers/auth_provider.dart  - Example Riverpod patterns
```

### UI & Navigation
```
/lib/core/router/app_router.dart       - Routing configuration
/lib/core/config/app_theme.dart        - Material3 theme
/lib/core/widgets/main_layout.dart     - Main app layout
```

### Example UI Features
```
/lib/features/menu/presentation/pages/menu_page.dart         - Page pattern
/lib/features/menu/presentation/widgets/menu_item_card.dart  - Widget pattern
```

### Configuration
```
/pubspec.yaml                          - Dependencies
/assets/translations/                  - Localization files
```

---

## Architecture Overview

```
┌──────────────────────────────────────────┐
│    PRESENTATION LAYER (UI)              │
│  - Material3 Design System              │
│  - Consumer/Stateful Widgets            │
│  - MainLayout with Navigation           │
│  - Theme.of(context) styling            │
└────────────────┬─────────────────────────┘
                 │
┌────────────────▼─────────────────────────┐
│  STATE MANAGEMENT (Riverpod)            │
│  - Provider (read-only)                 │
│  - StateProvider (mutable)              │
│  - StreamProvider (real-time)           │
│  - FutureProvider (async data)          │
└────────────────┬─────────────────────────┘
                 │
┌────────────────▼─────────────────────────┐
│    SERVICE LAYER (Business Logic)       │
│  - MenuService                          │
│  - MenuOptionService                    │
│  - AuthService                          │
│  - OrderService                         │
└────────────────┬─────────────────────────┘
                 │
┌────────────────▼─────────────────────────┐
│  PERSISTENCE LAYER (Data Storage)       │
│  - SQLite (primary)                     │
│  - Hive (auth state)                    │
│  - SharedPreferences (settings)         │
└──────────────────────────────────────────┘
```

---

## Technology Stack

| Layer | Technology | Version | Purpose |
|-------|-----------|---------|---------|
| UI | Flutter | Latest | Cross-platform framework |
| Design | Material3 | Built-in | Modern design system |
| State | flutter_riverpod | 2.4.9 | Dependency injection & reactivity |
| Navigation | go_router | 12.1.3 | Type-safe routing |
| Database | sqflite | 2.4.2 | SQLite wrapper |
| Auth State | hive | 2.2.3 | Fast KV store |
| i18n | easy_localization | 3.0.3 | Multi-language support |

---

## Coding Conventions

### Naming
- **Database columns:** `snake_case` (e.g., `option_group_id`)
- **Dart variables:** `camelCase` (e.g., `optionGroupId`)
- **Classes:** `PascalCase` (e.g., `OptionGroup`)
- **Constants:** `camelCase` (e.g., `maxSelectionCount`)

### Model Patterns
All models follow:
1. `factory Model.fromMap()` - Database to object
2. `Map<String, dynamic> toMap()` - Object to database
3. `Model copyWith({...})` - Immutable updates
4. Proper null safety with `??` operator

### Service Patterns
All services follow:
1. Try-catch error handling with logging
2. `Future<T>` return types for async
3. `Future<bool>` for operations
4. `Future<String?>` for ID generation
5. Database access via `await _databaseHelper.database`

### Widget Patterns
- Use callbacks for actions (not direct navigation)
- Use `Theme.of(context)` for all styling
- Support immutable construction
- Use `ConsumerWidget` for provider access

---

## How to Extend the App

### Adding a New Feature (e.g., Option Groups UI)

#### Step 1: Create Feature Folder
```bash
mkdir -p lib/features/option_groups/{providers,presentation/{pages,widgets}}
```

#### Step 2: Create Providers
See QUICK_REFERENCE.md for complete example of:
- Service provider
- FutureProvider for data
- StateProvider for selection
- Computed providers

#### Step 3: Create Pages
Use menu_page.dart as template:
- TabController for organizing sections
- FutureProvider.when() for loading states
- Search/filter functionality
- Error handling

#### Step 4: Create Widgets
Use menu_item_card.dart as template:
- Card-based UI
- Callback parameters for actions
- Theme-based styling
- Responsive layout

#### Step 5: Add Routes
Update `/lib/core/router/app_router.dart`:
```dart
GoRoute(
  path: '/option-groups',
  builder: (context, state) => const OptionGroupsPage(),
),
```

#### Step 6: Add Navigation
Update `/lib/core/widgets/main_layout.dart`:
```dart
MoreNavigationItem(
  icon: Icons.tune_outlined,
  label: 'Option Groups',
  route: '/option-groups',
  subtitle: 'Manage sizes, toppings, etc.',
),
```

#### Step 7: Add Translations
Update `/assets/translations/`:
- `en.json`
- `en-US.json`
- `vi.json`

---

## Database Schema (Option Groups)

### menu_options
```sql
CREATE TABLE menu_options (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  price REAL NOT NULL DEFAULT 0,
  description TEXT,
  category TEXT,
  is_available INTEGER DEFAULT 1,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

### option_groups
```sql
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
);
```

### option_group_options (many-to-many)
```sql
CREATE TABLE option_group_options (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  option_group_id INTEGER NOT NULL,
  option_id INTEGER NOT NULL,
  display_order INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (option_group_id) REFERENCES option_groups (id) ON DELETE CASCADE,
  FOREIGN KEY (option_id) REFERENCES menu_options (id) ON DELETE CASCADE
);
```

### menu_item_option_groups (many-to-many)
```sql
CREATE TABLE menu_item_option_groups (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  menu_item_id INTEGER NOT NULL,
  option_group_id INTEGER NOT NULL,
  is_required INTEGER DEFAULT 0,
  display_order INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (menu_item_id) REFERENCES menu_items (id) ON DELETE CASCADE,
  FOREIGN KEY (option_group_id) REFERENCES option_groups (id) ON DELETE CASCADE
);
```

---

## Available Service Methods

### MenuOptionService

**Option Operations:**
- `getAllMenuOptions()` - Get all available options
- `getMenuOptionsByCategory(String category)` - Filter by category
- `createMenuOption(MenuOption option)` - Create new
- `updateMenuOption(MenuOption option)` - Update existing
- `deleteMenuOption(String optionId)` - Soft delete

**Group Operations:**
- `getAllOptionGroups()` - Get all groups with options
- `getOptionGroupsForMenuItem(String menuItemId)` - Get for specific item
- `getOptionsForGroup(String optionGroupId)` - Get options in group
- `createOptionGroup(OptionGroup optionGroup)` - Create new
- `updateOptionGroup(OptionGroup optionGroup)` - Update existing

**Relationship Operations:**
- `connectMenuItemToOptionGroup(menuItemId, groupId, ...)` - Link item to group
- `disconnectMenuItemFromOptionGroup(menuItemId, groupId)` - Remove link
- `connectOptionToGroup(optionId, groupId, ...)` - Link option to group
- `disconnectOptionFromGroup(optionId, groupId)` - Remove link
- `getMenuItemsUsingOptionGroup(groupId)` - Find using items
- `connectOptionGroupToMenuItems(groupId, menuItemIds)` - Bulk link

All methods:
- Return `Future<T>` for async support
- Include try-catch error handling
- Log errors for debugging
- Use appropriate return types

---

## Riverpod Provider Patterns

### Pattern 1: Service Provider (Dependency Injection)
```dart
final menuOptionServiceProvider = Provider<MenuOptionService>((ref) {
  return MenuOptionService();
});
```

### Pattern 2: Future Provider (Async Data)
```dart
final optionGroupsProvider = FutureProvider<List<OptionGroup>>((ref) async {
  final service = ref.watch(menuOptionServiceProvider);
  return service.getAllOptionGroups();
});
```

### Pattern 3: Computed Provider (Derived State)
```dart
final activeOptionGroupsProvider = Provider<List<OptionGroup>>((ref) {
  final groups = ref.watch(optionGroupsProvider);
  return groups.maybeWhen(
    data: (g) => g.where((group) => group.isActive).toList(),
    orElse: () => [],
  );
});
```

### Pattern 4: State Provider (Mutable State)
```dart
final selectedGroupIdProvider = StateProvider<String?>((ref) => null);
```

### Usage in Widgets
```dart
// In ConsumerWidget
final groups = ref.watch(optionGroupsProvider);
final selectedId = ref.watch(selectedGroupIdProvider);

// Handle loading/error/data states
groups.when(
  data: (groups) => ListView(...),
  loading: () => Loading(),
  error: (err, stack) => Error(),
);
```

---

## UI Component Template

```dart
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with name and actions
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        optionGroup.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
            // Additional info
            SizedBox(height: 12),
            Text(
              'Options: ${optionGroup.options.length} • '
              'Min: ${optionGroup.minSelection} • '
              'Max: ${optionGroup.maxSelection}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Next Steps Roadmap

### Phase 1: Core UI (1-2 weeks)
- [ ] Create OptionGroupsPage (list view)
- [ ] Create OptionGroupDetailPage (view/edit)
- [ ] Create OptionGroupFormPage (create/edit)
- [ ] Implement Riverpod providers
- [ ] Add routes to app_router.dart
- [ ] Add navigation to MainLayout

### Phase 2: Option Management (1 week)
- [ ] Create OptionSelectionPage
- [ ] Build option grouping UI
- [ ] Implement add/remove options in group
- [ ] Implement display ordering

### Phase 3: Menu Item Integration (1-2 weeks)
- [ ] Add option group selector to menu item editor
- [ ] Show linked groups in menu item view
- [ ] Bulk assign groups to multiple items
- [ ] Manage required/optional settings

### Phase 4: POS Integration (1-2 weeks)
- [ ] Display option groups in order creation
- [ ] Handle option selection UI
- [ ] Validate min/max selections
- [ ] Calculate price adjustments
- [ ] Display in order summary

### Phase 5: Localization (3-5 days)
- [ ] Add all new strings to en.json
- [ ] Add Vietnamese translations to vi.json
- [ ] Use .tr() in all UI strings
- [ ] Test both languages

---

## Default Credentials

```
Email: admin@oishimenu.com
Password: admin123
Role: admin
```

---

## Troubleshooting Guide

### Provider Not Updating
- **Issue:** `ref.watch()` not triggering rebuild
- **Solution:** Ensure using `ref.watch()` not `ref.read()`
- **Check:** Provider is returning new instance, not cached

### Database Locked
- **Issue:** "database is locked" error
- **Solution:** Ensure all database calls use `await`
- **Check:** No async operations without proper awaiting

### Theme Not Applying
- **Issue:** Custom colors not showing
- **Solution:** Always use `Theme.of(context)` for colors
- **Check:** Not overriding with hardcoded Color values

### Navigation Loop
- **Issue:** Infinite redirect or navigation stack issues
- **Solution:** Check `app_router.dart` redirect logic
- **Check:** Auth state is being set correctly

### Translation Not Loading
- **Issue:** Strings show translation keys instead of text
- **Solution:** Ensure keys are in translation JSON files
- **Check:** Using correct locale (en, vi, en-US)

---

## Code Quality Checklist

Before committing code:
- [ ] Uses null safety operators (`??`, `?.`)
- [ ] Proper type annotations on all public methods
- [ ] Models use immutable pattern with `copyWith()`
- [ ] Services have try-catch with logging
- [ ] Widgets use callbacks for flexibility
- [ ] All styling uses `Theme.of(context)`
- [ ] Database queries use parameters (no string concat)
- [ ] Comments for complex logic
- [ ] No hardcoded strings (use translations)
- [ ] Follows existing naming conventions

---

## Useful Development Commands

```bash
# Format code
dart format lib/

# Analyze code for issues
flutter analyze

# Run on device/simulator
flutter run

# Run in debug mode
flutter run -d chrome  # Web
flutter run -d emulator-5554  # Android

# Build for specific platform
flutter build ios
flutter build apk

# Run tests
flutter test
```

---

## Related Documentation

- **ARCHITECTURE_GUIDE.md** - Deep technical documentation
- **QUICK_REFERENCE.md** - Quick lookup templates and patterns

---

## Summary

The OishiMenu Flutter app has a solid foundation with:
- ✓ Option groups fully modeled at database and service layer
- ✓ Clear architecture patterns ready to extend
- ✓ Comprehensive component library (Material3)
- ✓ State management infrastructure (Riverpod)
- ✓ Navigation structure (GoRouter)
- ✓ Localization setup (easy_localization)

**What's needed:** UI implementation for managing and using option groups in the app.

All patterns are established and examples are provided. Development should follow existing conventions for consistency.

---

**Last Updated:** October 20, 2025
**Status:** Ready for UI Implementation Phase
