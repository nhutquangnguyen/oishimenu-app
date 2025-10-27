# 🧪 OishiMenu App Test Checklist

## 📱 **Pre-Testing Setup**
- [ ] App installed on test device
- [ ] Internet connection available
- [ ] Clear app data/cache if needed
- [ ] Have test accounts ready (Google + email/password)

---

## 🔐 **Authentication Testing**

### **Login Flow**
- [ ] **Google Sign-In**: Successfully authenticate with Google account
- [ ] **Email/Password**: Login with valid credentials
- [ ] **Invalid Credentials**: Shows proper error message
- [ ] **Network Error**: Handles offline/poor connection gracefully
- [ ] **First Time User**: Account creation flow works
- [ ] **Remember Login**: Stays logged in after app restart

### **Logout Flow**
- [ ] **Sign Out**: Successfully logs out and returns to login screen
- [ ] **Session Persistence**: Login state persists between app launches

---

## 📋 **Menu Management Testing**

### **Categories**
- [ ] **View Categories**: All categories display with correct names and order
- [ ] **Create Category**: Can add new category successfully
- [ ] **Edit Category**: Can modify category name
- [ ] **Delete Category**: Can delete empty categories
- [ ] **Delete Restriction**: Cannot delete categories with menu items
- [ ] **Category Order**: Display order matches database order

### **Menu Items**
- [ ] **View Items**: All menu items display under correct categories
- [ ] **Create Item**: Can add new menu item with all fields
- [ ] **Edit Item**: Can modify name, price, description, category
- [ ] **Delete Item**: Can remove menu items successfully
- [ ] **Item Status**: Available/unavailable toggle works
- [ ] **Price Display**: Prices show correctly formatted
- [ ] **Category Assignment**: Items appear under correct categories

### **Drag & Drop Reordering**
- [ ] **Category Reordering**: Drag categories to new positions
- [ ] **Item Reordering**: Drag items within categories
- [ ] **Visual Feedback**: UI updates immediately during drag
- [ ] **Persistence**: Order persists after save and reload
- [ ] **Smooth Animation**: No loading spinners during reorder
- [ ] **Error Recovery**: Reverts to original order if save fails

---

## 🎛️ **Option Groups Testing**

### **Option Group CRUD**
- [ ] **Create Group**: Can create new option group with name only
- [ ] **Edit Group**: Can modify group name and settings
- [ ] **Delete Group**: Can delete option groups with confirmation
- [ ] **View Groups**: All option groups display in menu management

### **Group Settings**
- [ ] **Make Mandatory**: Toggle persists correctly after save
- [ ] **Allow Multiple**: Toggle persists correctly after save
- [ ] **Min/Max Selections**: Rules update based on settings
- [ ] **Selection Logic**: Single vs multiple selection modes work

### **Options Management**
- [ ] **Add Option**: Can add options to groups
- [ ] **Edit Option**: Can modify option name and price
- [ ] **Delete Option**: Delete button always red, confirmation works
- [ ] **Option Status**: Active/inactive toggle works correctly
- [ ] **No Duplicates**: Toggling inactive→active doesn't create duplicates
- [ ] **Option Persistence**: Changes save and reload correctly

### **Data Persistence**
- [ ] **Save Empty Group**: Can save group without options
- [ ] **Reload Accuracy**: All settings load exactly as saved
- [ ] **Boolean Fields**: isRequired/isAvailable values persist correctly
- [ ] **Database Sync**: Changes appear immediately after save

---

## 🔧 **CRUD Operations Testing**

### **Category CRUD Tests**
- [ ] **CRUD_CAT_001**: Create new category with valid data
- [ ] **CRUD_CAT_002**: Read/retrieve category by ID
- [ ] **CRUD_CAT_003**: Update existing category information
- [ ] **CRUD_CAT_004**: Delete category and verify removal

### **Menu Item CRUD Tests**
- [ ] **CRUD_MENU_001**: Create new menu item with all required fields
- [ ] **CRUD_MENU_002**: Read/retrieve menu item by ID
- [ ] **CRUD_MENU_003**: Update menu item name, price, and description
- [ ] **CRUD_MENU_004**: Delete menu item and verify removal

### **Option Group CRUD Tests**
- [ ] **CRUD_OPT_GROUP_001**: Create new option group with configuration
- [ ] **CRUD_OPT_GROUP_002**: Read/retrieve option group by ID
- [ ] **CRUD_OPT_GROUP_003**: Update option group settings and constraints
- [ ] **CRUD_OPT_GROUP_004**: Delete option group and verify removal

### **Option CRUD Tests**
- [ ] **CRUD_OPT_001**: Create new option with price and description
- [ ] **CRUD_OPT_002**: Read/retrieve option by ID
- [ ] **CRUD_OPT_003**: Update option name, price, and availability
- [ ] **CRUD_OPT_004**: Delete option and verify removal

### **CRUD Test Requirements**
- [ ] **Data Integrity**: All CRUD operations maintain referential integrity
- [ ] **Error Handling**: Invalid operations fail gracefully with proper error messages
- [ ] **Verification**: All operations verify success by re-reading data
- [ ] **Cleanup**: Tests clean up created data to avoid pollution
- [ ] **Dependencies**: Tests handle missing dependencies (categories, option groups)
- [ ] **Concurrent Operations**: Multiple CRUD operations don't interfere

---

## 💾 **Data Management Testing**

### **Save Operations**
- [ ] **Form Dirty State**: Save button enables when changes made
- [ ] **Validation**: Required fields properly validated
- [ ] **Success Feedback**: Success messages appear after saves
- [ ] **Error Handling**: Error messages for failed operations
- [ ] **Optimistic Updates**: UI updates immediately, reverts on failure

### **Load Operations**
- [ ] **Initial Load**: App loads existing data on startup
- [ ] **Refresh Data**: Manual refresh updates content
- [ ] **Real-time Sync**: Changes from other devices appear
- [ ] **Offline Handling**: Graceful degradation when offline

### **Order Sources Management**
- [ ] **Fetch Order Sources**: Can retrieve existing order sources without type errors
- [ ] **Create Order Sources**: Can create new order sources without constraint violations
- [ ] **Initialize Defaults**: Default order sources (onsite, takeaway, delivery platforms) initialize correctly
- [ ] **Type Conversion**: Boolean fields (is_active, requires_commission_input) handle both boolean and integer values
- [ ] **Enum Validation**: Order source types (onsite, takeaway, delivery) pass database constraints
- [ ] **Commission Settings**: Commission rates and input types save and load correctly
- [ ] **Data Integrity**: No type casting errors when fetching from Supabase

### **Order Management**
- [ ] **Create Orders**: Can create new orders with order items without constraint violations
- [ ] **Order Items**: Order items have valid menu_item_id references
- [ ] **Customer Association**: Orders properly link to customer records
- [ ] **Order Status**: Order status changes save and persist correctly
- [ ] **Payment Status**: Payment status updates work without errors
- [ ] **Order Totals**: Order totals calculate correctly with all items
- [ ] **Data Relationships**: All foreign key constraints satisfied during order creation
- [ ] **Order Status Filtering**: Orders with 'PREPARING' status appear in Processing Orders view
- [ ] **Status Enum Matching**: OrderStatus enum values match database stored values
- [ ] **Active Order Display**: Orders in processing states (CONFIRMED, PREPARING, READY) are visible
- [ ] **Order List Refresh**: Processing orders list updates when order status changes

### **End-to-End Order Workflows**
- [ ] **Order Creation to Save**: Complete workflow from creating new order to saving it successfully
  - Create customer if needed
  - Add menu items to order
  - Calculate totals correctly
  - Save order with PENDING status
  - Verify order appears in Active Orders
- [ ] **Order Creation to Completion**: Complete workflow from creating order to final completion
  - Create and save new order (PENDING status)
  - Update order status through lifecycle (CONFIRMED → PREPARING → READY)
  - Process payment and complete order
  - Verify order moves to History with DELIVERED status
  - Verify payment method selection works without defaults
- [ ] **Payment Method Validation for Order Completion**: Comprehensive payment method requirement enforcement
  - Try to complete order without payment method (should fail with validation error)
  - Complete order with valid payment method (cash) (should succeed)
  - Verify order status updates to DELIVERED only when payment method is provided
  - Verify payment method and status are correctly saved in database
- [ ] **Direct Order Creation/Update Payment Method Validation**: Service-level validation enforcement
  - Try to create order with DELIVERED status but no payment method (should fail)
  - Try to update order to DELIVERED status without payment method (should fail)
  - Create pending order without payment method (should succeed)
  - Update order to DELIVERED with valid payment method (should succeed)
  - Verify all validation errors provide clear user-friendly messages

---

## 🔄 **Navigation Testing**

### **Screen Transitions**
- [ ] **Menu→Categories**: Navigate to category management
- [ ] **Categories→Items**: Navigate to item management
- [ ] **Items→Options**: Navigate to option group management
- [ ] **Back Navigation**: Back buttons work correctly
- [ ] **Deep Links**: Direct navigation to specific screens

### **State Management**
- [ ] **Form State**: Unsaved changes prompts appear
- [ ] **Loading States**: Loading indicators during operations
- [ ] **Error States**: Error screens/messages when appropriate
- [ ] **Empty States**: Proper messages when no data

---

## 📱 **UI/UX Testing**

### **Visual Elements**
- [ ] **Layout**: All elements properly positioned
- [ ] **Typography**: Text readable and properly styled
- [ ] **Colors**: Consistent color scheme throughout
- [ ] **Icons**: All icons display correctly
- [ ] **Images**: Menu item images load properly

### **Interactions**
- [ ] **Touch Targets**: Buttons/links easy to tap
- [ ] **Scrolling**: Smooth scrolling in lists
- [ ] **Swipe Gestures**: Swipe actions work as expected
- [ ] **Long Press**: Context menus appear when appropriate
- [ ] **Keyboard**: Text input works smoothly

### **Responsive Design**
- [ ] **Portrait Mode**: Layout works in portrait orientation
- [ ] **Landscape Mode**: Layout adapts to landscape
- [ ] **Different Screens**: Works on phones and tablets
- [ ] **Text Scaling**: Respects device text size settings

---

## ⚡ **Performance Testing**

### **Loading Times**
- [ ] **App Startup**: App launches within 3 seconds
- [ ] **Data Loading**: Menu data loads within 2 seconds
- [ ] **Image Loading**: Images load progressively
- [ ] **Save Operations**: Saves complete within 1 second

### **Memory & Battery**
- [ ] **Memory Usage**: No memory leaks during extended use
- [ ] **Battery Drain**: Reasonable battery consumption
- [ ] **Background Behavior**: Proper handling when backgrounded
- [ ] **Large Datasets**: Performance with 100+ menu items

---

## 🚨 **Error Handling Testing**

### **Network Issues**
- [ ] **No Internet**: Proper offline message and graceful degradation
- [ ] **Slow Connection**: Loading indicators and timeout handling
- [ ] **Server Errors**: User-friendly error messages
- [ ] **Retry Logic**: Ability to retry failed operations

### **Data Issues**
- [ ] **Invalid Data**: Handles corrupted data gracefully
- [ ] **Missing Images**: Placeholder images for missing content
- [ ] **Database Errors**: Proper error messages for DB issues
- [ ] **Sync Conflicts**: Handles data conflicts appropriately

### **User Input Issues**
- [ ] **Invalid Input**: Validation messages for bad data
- [ ] **Empty Fields**: Handles empty/null values
- [ ] **Special Characters**: Supports international characters
- [ ] **Long Text**: Handles very long names/descriptions

---

## 🌍 **Localization Testing**

### **Language Support**
- [ ] **English**: All text displays in English
- [ ] **Vietnamese**: All text displays in Vietnamese
- [ ] **Language Switch**: Can change language in settings
- [ ] **Missing Keys**: No missing translation warnings

### **Regional Settings**
- [ ] **Currency**: Prices display in correct currency (VND)
- [ ] **Date Format**: Dates formatted for region
- [ ] **Number Format**: Numbers formatted correctly

---

## 🔧 **Edge Cases & Stress Testing**

### **Extreme Data**
- [ ] **Large Numbers**: Handles very high prices/quantities
- [ ] **Long Names**: Very long menu item names
- [ ] **Many Categories**: 50+ categories performance
- [ ] **Many Items**: 200+ menu items performance
- [ ] **Many Options**: 20+ options per group

### **Rapid Actions**
- [ ] **Fast Clicking**: Multiple rapid button presses
- [ ] **Quick Navigation**: Rapid screen switching
- [ ] **Concurrent Operations**: Multiple saves at once
- [ ] **Network Interruption**: Network drops during operations

---

## 📊 **Final Verification**

### **Data Integrity**
- [ ] **Data Consistency**: All saved data appears correctly
- [ ] **No Data Loss**: No items/categories missing
- [ ] **Correct Relationships**: Option groups linked to correct items
- [ ] **Order Preservation**: Display orders maintained

### **User Experience**
- [ ] **Intuitive Flow**: App flow makes sense to new users
- [ ] **Error Recovery**: Easy to recover from errors
- [ ] **Feature Discovery**: Features are discoverable
- [ ] **Overall Polish**: App feels professional and complete

---

## 🎯 **Critical Path Testing**

**Priority 1 (Must Work)**
- [ ] Login/logout functionality
- [ ] View menu categories and items
- [ ] Create/edit menu items
- [ ] Save changes successfully

**Priority 2 (Should Work)**
- [ ] Drag & drop reordering
- [ ] Option groups management
- [ ] Delete operations
- [ ] Form validation

**Priority 3 (Nice to Have)**
- [ ] Advanced animations
- [ ] Offline support
- [ ] Performance optimizations
- [ ] Advanced error handling

---

## 📝 **Bug Reporting Template**

When you find issues, document them with:

**Bug Title**: [Brief description]
**Steps to Reproduce**:
1. Step 1
2. Step 2
3. Step 3

**Expected Result**: What should happen
**Actual Result**: What actually happened
**Device**: [Phone model, OS version]
**Frequency**: Always/Sometimes/Rarely
**Screenshots**: [If applicable]
**Console Logs**: [If available]

### **Known Issues - Fixed**

**FIXED: Order Sources Type Casting & Constraint Errors**
- **Issue**: `type 'bool' is not a subtype of type 'int?'` and PostgreSQL constraint violations
- **Root Cause**: Supabase returns boolean values but model expected integers; enum values didn't match database constraints
- **Steps to Reproduce**:
  1. Run automated test DATA_004 (Order Source Service)
  2. Try to fetch order sources from Supabase
  3. Try to create default order sources
- **Fixed In**:
  - `lib/models/order_source.dart` - Added robust type parsing helpers
  - `lib/services/supabase_service.dart` - Updated order source CRUD operations
  - `lib/services/automated_test_service.dart` - Added DATA_004 test case
- **Test Coverage**: DATA_004 automated test verifies the fix

**FIXED: Order Creation Null menu_item_id Constraint Error**
- **Issue**: `null value in column "menu_item_id" of relation "order_items" violates not-null constraint`
- **Root Cause**: Order items missing required menu_item_id when creating orders
- **Steps to Reproduce**:
  1. Run automated test DATA_005 (Order Creation Service)
  2. Try to create a new order with order items
  3. Database rejects insertion due to null menu_item_id
- **Fixed In**:
  - `lib/models/order.dart` - Fixed OrderItem toMap() method
  - `lib/services/supabase_service.dart` - Updated order creation logic
  - `lib/services/automated_test_service.dart` - Added DATA_005 test case
- **Test Coverage**: DATA_005 automated test verifies the fix

**FIXED: Processing Orders Not Showing in UI**
- **Issue**: Active orders with 'PREPARING' status not appearing in Processing Orders view
- **Root Cause**: OrderStatus enum values don't match database stored values for filtering
- **Steps to Reproduce**:
  1. Create order and set status to 'PREPARING'
  2. Navigate to Processing Orders view
  3. Order doesn't appear in the list
- **Fixed In**:
  - `lib/models/order.dart` - Updated OrderStatus enum values
  - `lib/services/supabase_service.dart` - Fixed order status filtering
  - `lib/services/automated_test_service.dart` - Added DATA_006 test case
- **Test Coverage**: DATA_006 automated test verifies the fix

---

## ✅ **Sign-Off Checklist**

- [ ] All Priority 1 items passing
- [ ] 90%+ of Priority 2 items passing
- [ ] No critical bugs remaining
- [ ] Performance acceptable on target devices
- [ ] Data integrity verified
- [ ] Ready for production use

---

*Last Updated: $(date)*
*Version: 1.0*