import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Helper class for easy access to app translations
class AppLocalizations {
  // Private constructor to prevent instantiation
  AppLocalizations._();

  /// Get localized string by key
  static String tr(String key, {BuildContext? context}) {
    return key.tr();
  }

  /// Get localized string with arguments
  static String trArgs(String key, List<String> args, {BuildContext? context}) {
    return key.tr(args: args);
  }

  /// Get localized string with named arguments
  static String trNamed(String key, Map<String, String> namedArgs, {BuildContext? context}) {
    return key.tr(namedArgs: namedArgs);
  }

  /// Check if current locale is Vietnamese
  static bool isVietnamese(BuildContext context) {
    return context.locale.languageCode == 'vi';
  }

  /// Check if current locale is English
  static bool isEnglish(BuildContext context) {
    return context.locale.languageCode == 'en';
  }

  /// Switch to Vietnamese
  static Future<void> setVietnamese(BuildContext context) async {
    await context.setLocale(const Locale('vi', 'VN'));
  }

  /// Switch to English
  static Future<void> setEnglish(BuildContext context) async {
    await context.setLocale(const Locale('en', 'US'));
  }

  /// Get current locale
  static Locale getCurrentLocale(BuildContext context) {
    return context.locale;
  }

  /// Get supported locales
  static List<Locale> getSupportedLocales() {
    return const [
      Locale('vi', 'VN'),
      Locale('en', 'US'),
    ];
  }

  // Common app strings
  static String get appName => 'app_name'.tr();
  static String get welcome => 'welcome'.tr();
  static String get login => 'login'.tr();
  static String get signup => 'signup'.tr();
  static String get email => 'email'.tr();
  static String get password => 'password'.tr();
  static String get save => 'save'.tr();
  static String get cancel => 'cancel'.tr();
  static String get delete => 'delete'.tr();
  static String get confirm => 'confirm'.tr();
  static String get back => 'back'.tr();
  static String get next => 'next'.tr();
  static String get loading => 'loading'.tr();
  static String get error => 'error'.tr();
  static String get success => 'success'.tr();
  static String get warning => 'warning'.tr();
  static String get info => 'info'.tr();
  static String get ok => 'ok'.tr();
  static String get close => 'close'.tr();
  static String get refresh => 'refresh'.tr();
  static String get search => 'search'.tr();
  static String get filter => 'filter'.tr();
  static String get customers => 'customers'.tr();

  // Navigation strings
  static String get dashboard => 'dashboard'.tr();
  static String get menu => 'menu'.tr();
  static String get orders => 'orders'.tr();
  static String get pos => 'pos'.tr();
  static String get inventory => 'inventory'.tr();
  static String get employees => 'employees'.tr();
  static String get feedback => 'feedback'.tr();
  static String get analytics => 'analytics'.tr();
  static String get settings => 'settings'.tr();

  // Dashboard strings
  static String get quickActions => 'quick_actions'.tr();
  static String get todaysRevenue => 'todays_revenue'.tr();
  static String get avgOrder => 'avg_order'.tr();
  static String get salesOverview => 'sales_overview'.tr();
  static String get recentOrders => 'recent_orders'.tr();
  static String get restaurantSummary => 'restaurant_summary'.tr();

  static String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'good_morning'.tr();
    if (hour < 17) return 'good_afternoon'.tr();
    return 'good_evening'.tr();
  }

  // Inventory strings
  static String get inventoryManagement => 'inventory_management'.tr();
  static String get ingredients => 'ingredients'.tr();
  static String get stocktake => 'stocktake'.tr();
  static String get lowStock => 'low_stock'.tr();
  static String get outOfStock => 'out_of_stock'.tr();
  static String get critical => 'critical'.tr();
  static String get inStock => 'in_stock'.tr();
  static String get quantity => 'quantity'.tr();
  static String get unit => 'unit'.tr();
  static String get costPerUnit => 'cost_per_unit'.tr();
  static String get minimumThreshold => 'minimum_threshold'.tr();
  static String get supplier => 'supplier'.tr();
  static String get category => 'category'.tr();
  static String get addIngredient => 'add_ingredient'.tr();
  static String get editIngredient => 'edit_ingredient'.tr();
  static String get deleteIngredient => 'delete_ingredient'.tr();
  static String get exportData => 'export_data'.tr();
  static String get allCategories => 'all_categories'.tr();

  // Option Groups strings
  static String get optionGroups => 'option_groups'.tr();
  static String get createOptionGroup => 'create_option_group'.tr();
  static String get editOptionGroup => 'edit_option_group'.tr();
  static String get options => 'options'.tr();
  static String get addOption => 'add_option'.tr();
  static String get optionName => 'option_name'.tr();
  static String get additionalPrice => 'additional_price'.tr();
  static String get makeMandatory => 'make_mandatory'.tr();
  static String get allowMultiple => 'allow_multiple'.tr();
  static String get preview => 'preview'.tr();
  static String get name => 'name'.tr();
  static String get description => 'description'.tr();
  static String get price => 'price'.tr();
  static String get required => 'required'.tr();
  static String get optional => 'optional'.tr();

  // Currency and formatting
  static String get currency => 'currency'.tr();
  static String get vnd => 'vnd'.tr();
  static String get total => 'total'.tr();
  static String get subtotal => 'subtotal'.tr();
  static String get tax => 'tax'.tr();
  static String get discount => 'discount'.tr();

  static String formatVND(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}${'currency'.tr()}';
  }

  // Vietnamese Categories
  static String getDairy() => 'vietnamese_categories.dairy'.tr();
  static String getProtein() => 'vietnamese_categories.protein'.tr();
  static String getVegetables() => 'vietnamese_categories.vegetables'.tr();
  static String getFruits() => 'vietnamese_categories.fruits'.tr();
  static String getGrains() => 'vietnamese_categories.grains'.tr();
  static String getSpices() => 'vietnamese_categories.spices'.tr();
  static String getBeverages() => 'vietnamese_categories.beverages'.tr();
  static String getOther() => 'vietnamese_categories.other'.tr();

  static Map<String, String> getAllCategories() {
    return {
      'dairy': getDairy(),
      'protein': getProtein(),
      'vegetables': getVegetables(),
      'fruits': getFruits(),
      'grains': getGrains(),
      'spices': getSpices(),
      'beverages': getBeverages(),
      'other': getOther(),
    };
  }

  // Form fields
  static String get fullName => 'form_fields.full_name'.tr();
  static String get enterFullName => 'form_fields.enter_full_name'.tr();
  static String get enterEmail => 'form_fields.enter_email'.tr();
  static String get enterPassword => 'form_fields.enter_password'.tr();
  static String get createPassword => 'form_fields.create_password'.tr();
  static String get confirmPassword => 'form_fields.confirm_password'.tr();
  static String get confirmYourPassword => 'form_fields.confirm_your_password'.tr();
  static String get enterItemName => 'form_fields.enter_item_name'.tr();
  static String get enterDescription => 'form_fields.enter_description'.tr();
  static String get itemName => 'form_fields.item_name'.tr();
  static String get itemPhoto => 'form_fields.item_photo'.tr();
  static String get supplierNameOptional => 'form_fields.supplier_name_optional'.tr();
  static String get briefDescriptionOptional => 'form_fields.brief_description_optional'.tr();
  static String get ingredientName => 'form_fields.ingredient_name'.tr();

  // Buttons
  static String get signIn => 'buttons.sign_in'.tr();
  static String get signUp => 'buttons.sign_up'.tr();
  static String get createAccount => 'buttons.create_account'.tr();
  static String get continueWithGoogle => 'buttons.continue_with_google'.tr();
  static String get forgotPassword => 'buttons.forgot_password'.tr();
  static String get addItem => 'buttons.add_item'.tr();
  static String get edit => 'buttons.edit'.tr();
  static String get update => 'buttons.update'.tr();
  static String get add => 'buttons.add'.tr();
  static String get create => 'buttons.create'.tr();
  static String get continueButton => 'buttons.continue'.tr();
  static String get retry => 'buttons.retry'.tr();
  static String get clearAll => 'buttons.clear_all'.tr();
  static String get exportCsv => 'buttons.export_csv'.tr();
  static String get sampleData => 'buttons.sample_data'.tr();
  static String get newSession => 'buttons.new_session'.tr();
  static String get viewAll => 'buttons.view_all'.tr();
  static String get improve => 'buttons.improve'.tr();
  static String get rearrangeOptionGroups => 'buttons.rearrange_option_groups'.tr();
  static String get deleteItem => 'buttons.delete_item'.tr();
  static String get stay => 'buttons.stay'.tr();
  static String get leave => 'buttons.leave'.tr();
  static String get processData => 'buttons.process_data'.tr();
  static String get clearButton => 'buttons.clear'.tr();
  static String get import => 'buttons.import'.tr();
  static String get processManualInput => 'buttons.process_manual_input'.tr();

  // Page titles
  static String get createAccountTitle => 'page_titles.create_account'.tr();
  static String get welcomeBack => 'page_titles.welcome_back'.tr();
  static String get addItemTitle => 'page_titles.add_item'.tr();
  static String get editItemTitle => 'page_titles.edit_item'.tr();
  static String get scanMenuTitle => 'page_titles.scan_menu'.tr();
  static String get inventoryTitle => 'page_titles.inventory'.tr();

  // Descriptions
  static String get restaurantManagementSystem => 'descriptions.restaurant_management_system'.tr();
  static String get signInToContinue => 'descriptions.sign_in_to_continue'.tr();
  static String get joinOishimenu => 'descriptions.join_oishimenu'.tr();
  static String get orContinueWith => 'descriptions.or_continue_with'.tr();
  static String get chooseScanMethod => 'descriptions.choose_scan_method'.tr();
  static String get scanMenuQr => 'descriptions.scan_menu_qr'.tr();
  static String get scanProductBarcodes => 'descriptions.scan_product_barcodes'.tr();
  static String get extractTextFromPhotos => 'descriptions.extract_text_from_photos'.tr();
  static String get scanMenuDocuments => 'descriptions.scan_menu_documents'.tr();

  // Messages
  static String get dontHaveAccount => 'messages.dont_have_account'.tr();
  static String get alreadyHaveAccount => 'messages.already_have_account'.tr();
  static String get iAgreeTo => 'messages.i_agree_to'.tr();
  static String get termsOfService => 'messages.terms_of_service'.tr();
  static String get privacyPolicy => 'messages.privacy_policy'.tr();
  static String get noItemsFound => 'messages.no_items_found'.tr();
  static String get noMenuItemsYet => 'messages.no_menu_items_yet'.tr();
  static String get tryDifferentSearch => 'messages.try_different_search'.tr();
  static String get addFirstMenuItem => 'messages.add_first_menu_item'.tr();
  static String get noSessionsYet => 'messages.no_sessions_yet'.tr();
  static String get createSessionToStart => 'messages.create_session_to_start'.tr();
  static String get noDataToExport => 'messages.no_data_to_export'.tr();
  static String get allItemsWellStocked => 'messages.all_items_well_stocked'.tr();
  static String get maxPhotosInfo => 'messages.max_photos_info'.tr();
  static String get noOptionsInGroup => 'messages.no_options_in_group'.tr();
  static String get noIngredientsYet => 'messages.no_ingredients_yet'.tr();
  static String get addFirstIngredient => 'messages.add_first_ingredient'.tr();

  // Validation
  static String get pleaseEnterEmail => 'validation.please_enter_email'.tr();
  static String get pleaseEnterValidEmail => 'validation.please_enter_valid_email'.tr();
  static String get pleaseEnterPassword => 'validation.please_enter_password'.tr();
  static String get passwordMin6Chars => 'validation.password_min_6_chars'.tr();
  static String get passwordLettersNumbers => 'validation.password_letters_numbers'.tr();
  static String get pleaseConfirmPassword => 'validation.please_confirm_password'.tr();
  static String get passwordsDoNotMatch => 'validation.passwords_do_not_match'.tr();
  static String get pleaseEnterFullName => 'validation.please_enter_full_name'.tr();
  static String get nameMin2Chars => 'validation.name_min_2_chars'.tr();
  static String get itemNameRequired => 'validation.item_name_required'.tr();
  static String get priceRequired => 'validation.price_required'.tr();
  static String get pleaseEnterValidPrice => 'validation.please_enter_valid_price'.tr();
  static String get pleaseFillRequiredFields => 'validation.please_fill_required_fields'.tr();

  // Errors
  static String get failedGoogleSignin => 'errors.failed_google_signin'.tr();
  static String get unexpectedError => 'errors.unexpected_error'.tr();

  // Status
  static String get available => 'status.available'.tr();
  static String get unavailable => 'status.unavailable'.tr();
  static String get lowStockStatus => 'status.low_stock'.tr();
  static String get criticalStatus => 'status.critical'.tr();
  static String get requiredStatus => 'status.required'.tr();
  static String get optionalStatus => 'status.optional'.tr();

  // Tabs
  static String get itemsTab => 'tabs.items'.tr();
  static String get optionsTab => 'tabs.options'.tr();
  static String get stocktakeTab => 'tabs.stocktake'.tr();
  static String get sessionsTab => 'tabs.sessions'.tr();

  // Sections
  static String get editTranslations => 'sections.edit_translations'.tr();
  static String get optionGroupsSection => 'sections.option_groups'.tr();
  static String get availabilitySchedule => 'sections.availability_schedule'.tr();
  static String get allOpeningHours => 'sections.all_opening_hours'.tr();

  // Quick Actions Items
  static String get newOrderAction => 'quick_actions_items.new_order'.tr();
  static String get startPosOrder => 'quick_actions_items.start_pos_order'.tr();
  static String get manageItems => 'quick_actions_items.manage_items'.tr();
  static String get checkStock => 'quick_actions_items.check_stock'.tr();
  static String get viewInsights => 'quick_actions_items.view_insights'.tr();
  static String get tablesAction => 'quick_actions_items.tables'.tr();
  static String get manageSeating => 'quick_actions_items.manage_seating'.tr();
  static String get staffAction => 'quick_actions_items.staff'.tr();
  static String get manageTeam => 'quick_actions_items.manage_team'.tr();
  static String get reportsAction => 'quick_actions_items.reports'.tr();
  static String get viewReports => 'quick_actions_items.view_reports'.tr();
  static String get kitchenAction => 'quick_actions_items.kitchen'.tr();
  static String get kitchenDisplay => 'quick_actions_items.kitchen_display'.tr();
  static String get customerData => 'quick_actions_items.customer_data'.tr();
  static String get reservationsAction => 'quick_actions_items.reservations'.tr();
  static String get bookTables => 'quick_actions_items.book_tables'.tr();
  static String get printAction => 'quick_actions_items.print'.tr();
  static String get printReceipts => 'quick_actions_items.print_receipts'.tr();
  static String get printOptions => 'quick_actions_items.print_options'.tr();
  static String get appSettings => 'quick_actions_items.app_settings'.tr();

  // Scan Methods
  static String get qrCode => 'scan_methods.qr_code'.tr();
  static String get barcode => 'scan_methods.barcode'.tr();
  static String get photoMenu => 'scan_methods.photo_menu'.tr();
  static String get document => 'scan_methods.document'.tr();

  // Fields
  static String get costVnd => 'fields.cost_vnd'.tr();
  static String get minAlert => 'fields.min_alert'.tr();
  static String get current => 'fields.current'.tr();
  static String get stock => 'fields.stock'.tr();
  static String get cost => 'fields.cost'.tr();
  static String get value => 'fields.value'.tr();
  static String get items => 'fields.items'.tr();
  static String get sessions => 'fields.sessions'.tr();

  // Inventory
  static String showingLowStockItems(int count) => 'inventory_messages.showing_low_stock_items'.tr(namedArgs: {'count': count.toString()});
  static String get ingredientUpdatedSuccessfully => 'inventory_messages.ingredient_updated_successfully'.tr();
  static String get ingredientAddedSuccessfully => 'inventory_messages.ingredient_added_successfully'.tr();
  static String get errorLoadingStats => 'inventory_messages.error_loading_stats'.tr();
  static String get errorLoadingSessions => 'inventory_messages.error_loading_sessions'.tr();
  static String errorUpdatingQuantity(String error) => 'inventory_messages.error_updating_quantity'.tr(namedArgs: {'error': error});
  static String get failedUpdateOptionAvailability => 'inventory_messages.failed_update_option_availability'.tr();
  static String get errorUpdatingOptionAvailability => 'inventory_messages.error_updating_option_availability'.tr();
  static String get exportComplete => 'inventory_messages.export_complete'.tr();
  static String exportedIngredients(int count) => 'inventory_messages.exported_ingredients'.tr(namedArgs: {'count': count.toString()});
  static String get csvData => 'inventory_messages.csv_data'.tr();
  static String exportFailed(String error) => 'inventory_messages.export_failed'.tr(namedArgs: {'error': error});
  static String get clearAllData => 'inventory_messages.clear_all_data'.tr();
  static String get clearAllWarning => 'inventory_messages.clear_all_warning'.tr();
  static String get clearDataComingSoon => 'inventory_messages.clear_data_coming_soon'.tr();
  static String get createSampleData => 'inventory_messages.create_sample_data'.tr();
  static String get createSampleDataDescription => 'inventory_messages.create_sample_data_description'.tr();
  static String get createStocktakeSession => 'inventory_messages.create_stocktake_session'.tr();
  static String get createStocktakeDescription => 'inventory_messages.create_stocktake_description'.tr();
  static String adjustIngredient(String name) => 'inventory_messages.adjust_ingredient'.tr(namedArgs: {'name': name});
  static String currentQuantity(String quantity) => 'inventory_messages.current_quantity'.tr(namedArgs: {'quantity': quantity});
  static String lowStockCount(int count) => 'inventory_messages.low_stock_count'.tr(namedArgs: {'count': count.toString()});
  static String get nameRequired => 'inventory_messages.name_required'.tr();
  static String get namePlaceholder => 'inventory_messages.name_placeholder'.tr();
  static String get selectCategory => 'inventory_messages.select_category'.tr();
  static String get selectUnit => 'inventory_messages.select_unit'.tr();
  static String get costPlaceholder => 'inventory_messages.cost_placeholder'.tr();
  static String get minThresholdPlaceholder => 'inventory_messages.min_threshold_placeholder'.tr();
  static String get descriptionPlaceholder => 'inventory_messages.description_placeholder'.tr();
  static String get supplierPlaceholder => 'inventory_messages.supplier_placeholder'.tr();

  // Units
  static String get unitKg => 'units.kg'.tr();
  static String get unitG => 'units.g'.tr();
  static String get unitL => 'units.l'.tr();
  static String get unitMl => 'units.ml'.tr();
  static String get unitPiece => 'units.piece'.tr();
  static String get unitPack => 'units.pack'.tr();
  static String get unitBottle => 'units.bottle'.tr();
  static String get unitCan => 'units.can'.tr();
  static String get unitBox => 'units.box'.tr();
  static String get unitBag => 'units.bag'.tr();

  // Dialogs
  static String get deleteMenuItem => 'dialogs.delete_menu_item'.tr();
  static String deleteMenuItemConfirm(String name) => 'dialogs.delete_menu_item_confirm'.tr(namedArgs: {'name': name});
  static String get deleteIngredientDialog => 'dialogs.delete_ingredient'.tr();
  static String deleteIngredientConfirm(String name) => 'dialogs.delete_ingredient_confirm'.tr(namedArgs: {'name': name});
  static String get editIngredientDialog => 'dialogs.edit_ingredient'.tr();
  static String get addIngredientDialog => 'dialogs.add_ingredient'.tr();
  static String get unsavedChanges => 'dialogs.unsaved_changes'.tr();
  static String get unsavedChangesMessage => 'dialogs.unsaved_changes_message'.tr();

  // Success messages
  static String get menuItemDeleted => 'success_messages.menu_item_deleted'.tr();
  static String get ingredientDeleted => 'success_messages.ingredient_deleted'.tr();
  static String get quantityUpdated => 'success_messages.quantity_updated'.tr();

  // Stock status
  static String get stockUnknown => 'stock_status.unknown'.tr();

  // Menu
  static String get menuItems => 'menu_details.items'.tr();
  static String get menuOptionGroups => 'menu_details.option_groups'.tr();
  static String get menuSearch => 'menu_details.search'.tr();
  static String menuOutOfStock(int count) => 'menu_details.out_of_stock'.tr(namedArgs: {'count': count.toString()});
  static String get menuAvailability => 'menu_details.availability'.tr();
  static String get menuNoItemsFound => 'menu_details.no_items_found'.tr();
  static String get menuTryDifferentSearch => 'menu_details.try_different_search'.tr();
  static String menuCategory(String category) => 'menu_details.category'.tr(namedArgs: {'category': category});
  static String menuDescription(String description) => 'menu_details.description'.tr(namedArgs: {'description': description});
  static String menuPrice(String price) => 'menu_details.price'.tr(namedArgs: {'price': price});
  static String menuCost(String cost) => 'menu_details.cost'.tr(namedArgs: {'cost': cost});
  static String menuStatus(String status) => 'menu_details.status'.tr(namedArgs: {'status': status});
  static String get menuAvailableStatus => 'menu_details.available'.tr();
  static String get menuUnavailableStatus => 'menu_details.unavailable'.tr();
  static String get menuClose => 'menu_details.close'.tr();
  static String get menuEditMenuItem => 'menu_details.edit_menu_item'.tr();
  static String get menuEditComingSoon => 'menu_details.edit_coming_soon'.tr();
  static String get menuDeleteMenuItem => 'menu_details.delete_menu_item'.tr();
  static String menuDeleteConfirmation(String name) => 'menu_details.delete_confirmation'.tr(namedArgs: {'name': name});
  static String get menuDelete => 'menu_details.delete'.tr();
  static String menuErrorUpdatingAvailability(String error) => 'menu_details.error_updating_availability'.tr(namedArgs: {'error': error});
  static String get menuFailedUpdateOptionAvailability => 'menu_details.failed_update_option_availability'.tr();
  static String get menuErrorUpdatingOptionAvailability => 'menu_details.error_updating_option_availability'.tr();
  static String get menuItemDeletedSuccessfully => 'menu_details.menu_item_deleted_successfully'.tr();
  static String menuErrorDeletingItem(String error) => 'menu_details.error_deleting_item'.tr(namedArgs: {'error': error});
  static String get menuEditOptionGroup => 'menu_details.edit_option_group'.tr();
  static String get menuEditingFeatureInDevelopment => 'menu_details.editing_feature_in_development'.tr();
  static String get menuOpenEditor => 'menu_details.open_editor'.tr();
  static String get menuDeleteOptionGroup => 'menu_details.delete_option_group'.tr();
  static String menuDeleteOptionGroupConfirm(String name) => 'menu_details.delete_option_group_confirm'.tr(namedArgs: {'name': name});
  static String get menuActionCannotBeUndone => 'menu_details.action_cannot_be_undone'.tr();
  static String menuError(String error) => 'menu_details.error'.tr(namedArgs: {'error': error});
  static String menuCostDisplay(String cost) => 'menu_details.cost_display'.tr(namedArgs: {'cost': cost});
  static String menuMarginDisplay(String margin) => 'menu_details.margin_display'.tr(namedArgs: {'margin': margin});
  static String get menuEdit => 'menu_details.edit'.tr();
  static String get menuDeleteTooltip => 'menu_details.delete_tooltip'.tr();

  // Scan Menu
  static String get scanMenuPageTitle => 'scan_menu.title'.tr();
  static String get scanMenuChooseMethod => 'scan_menu.choose_scan_method'.tr();
  static String get scanMenuQrCodeType => 'scan_menu.qr_code'.tr();
  static String get scanMenuQrCodeDescription => 'scan_menu.scan_menu_qr'.tr();
  static String get scanMenuBarcodeType => 'scan_menu.barcode'.tr();
  static String get scanMenuBarcodeDescription => 'scan_menu.scan_product_barcodes'.tr();
  static String get scanMenuPhotoMenuType => 'scan_menu.photo_menu'.tr();
  static String get scanMenuPhotoDescription => 'scan_menu.extract_text_from_photos'.tr();
  static String get scanMenuDocumentType => 'scan_menu.document'.tr();
  static String get scanMenuDocumentDescription => 'scan_menu.scan_menu_documents'.tr();
  static String scanMenuScanned(String type) => 'scan_menu.scanned'.tr(namedArgs: {'type': type});
  static String get scanMenuProcessData => 'scan_menu.process_data'.tr();
  static String get scanMenuClear => 'scan_menu.clear'.tr();
  static String get scanMenuExtractedItems => 'scan_menu.extracted_menu_items'.tr();
  static String scanMenuItemsCount(int count) => 'scan_menu.items_count'.tr(namedArgs: {'count': count.toString()});
  static String scanMenuImportAllItems(int count) => 'scan_menu.import_all_items'.tr(namedArgs: {'count': count.toString()});
  static String scanMenuCategory(String category) => 'scan_menu.category'.tr(namedArgs: {'category': category});
  static String get scanMenuImport => 'scan_menu.import'.tr();
  static String get scanMenuManualInput => 'scan_menu.manual_input'.tr();
  static String get scanMenuPasteMenuData => 'scan_menu.paste_menu_data'.tr();
  static String get scanMenuManualInputPlaceholder => 'scan_menu.manual_input_placeholder'.tr();
  static String get scanMenuProcessManualInput => 'scan_menu.process_manual_input'.tr();
  static String scanMenuScanning(String type) => 'scan_menu.scanning'.tr(namedArgs: {'type': type});
  static String get scanMenuPointCamera => 'scan_menu.point_camera'.tr();
  static String get scanMenuEditComingSoon => 'scan_menu.edit_functionality_coming_soon'.tr();
  static String scanMenuImportedSuccessfully(String name) => 'scan_menu.imported_successfully'.tr(namedArgs: {'name': name});
  static String scanMenuFailedToImport(String name) => 'scan_menu.failed_to_import'.tr(namedArgs: {'name': name});
  static String scanMenuErrorImporting(String name, String error) => 'scan_menu.error_importing'.tr(namedArgs: {'name': name, 'error': error});
  static String scanMenuImportCompleted(int success, int error) => 'scan_menu.import_completed'.tr(namedArgs: {'success': success.toString(), 'error': error.toString()});
  static String get scanMenuHelpTitle => 'scan_menu.help_title'.tr();
  static String get scanMenuScanMethods => 'scan_menu.scan_methods'.tr();
  static String get scanMenuQrCodeHelp => 'scan_menu.qr_code_help'.tr();
  static String get scanMenuBarcodeHelp => 'scan_menu.barcode_help'.tr();
  static String get scanMenuPhotoMenuHelp => 'scan_menu.photo_menu_help'.tr();
  static String get scanMenuDocumentHelp => 'scan_menu.document_help'.tr();
  static String get scanMenuManualInputFormat => 'scan_menu.manual_input_format'.tr();
  static String get scanMenuItemNamePrice => 'scan_menu.item_name_price'.tr();
  static String get scanMenuExample => 'scan_menu.example'.tr();
  static String get scanMenuCategoriesWithColons => 'scan_menu.categories_with_colons'.tr();
  static String get scanMenuCategoryExample => 'scan_menu.category_example'.tr();

  // Menu Item Editor
  static String get menuItemEditorAddItem => 'menu_item_editor.add_item'.tr();
  static String get menuItemEditorEditItem => 'menu_item_editor.edit_item'.tr();
  static String get menuItemEditorItemName => 'menu_item_editor.item_name'.tr();
  static String get menuItemEditorRequired => 'menu_item_editor.required'.tr();
  static String get menuItemEditorEnterItemName => 'menu_item_editor.enter_item_name'.tr();
  static String get menuItemEditorItemNameRequired => 'menu_item_editor.item_name_required'.tr();
  static String get menuItemEditorItemPhoto => 'menu_item_editor.item_photo'.tr();
  static String get menuItemEditorMaxPhotosInfo => 'menu_item_editor.max_photos_info'.tr();
  static String get menuItemEditorDescription => 'menu_item_editor.description'.tr();
  static String get menuItemEditorEnterDescription => 'menu_item_editor.enter_description'.tr();
  static String get menuItemEditorImprove => 'menu_item_editor.improve'.tr();
  static String get menuItemEditorEditTranslations => 'menu_item_editor.edit_translations'.tr();
  static String get menuItemEditorCategory => 'menu_item_editor.category'.tr();
  static String get menuItemEditorSelectCategory => 'menu_item_editor.select_category'.tr();
  static String get menuItemEditorPrice => 'menu_item_editor.price'.tr();
  static String get menuItemEditorPricePlaceholder => 'menu_item_editor.price_placeholder'.tr();
  static String get menuItemEditorPriceRequired => 'menu_item_editor.price_required'.tr();
  static String get menuItemEditorValidPriceRequired => 'menu_item_editor.valid_price_required'.tr();
  static String get menuItemEditorOptionGroups => 'menu_item_editor.option_groups'.tr();
  static String get menuItemEditorSelectOptionGroups => 'menu_item_editor.select_option_groups'.tr();
  static String menuItemEditorSelectedCount(int count) => 'menu_item_editor.selected_count'.tr(namedArgs: {'count': count.toString()});
  static String get menuItemEditorRearrangeOptionGroups => 'menu_item_editor.rearrange_option_groups'.tr();
  static String get menuItemEditorAvailabilitySchedule => 'menu_item_editor.availability_schedule'.tr();
  static String get menuItemEditorAllOpeningHours => 'menu_item_editor.all_opening_hours'.tr();
  static String get menuItemEditorDeleteItem => 'menu_item_editor.delete_item'.tr();
  static String get menuItemEditorContinue => 'menu_item_editor.continue'.tr();
  static String get menuItemEditorDeleteItemTitle => 'menu_item_editor.delete_item_title'.tr();
  static String get menuItemEditorDeleteItemConfirm => 'menu_item_editor.delete_item_confirm'.tr();
  static String menuItemEditorErrorDeleting(String error) => 'menu_item_editor.error_deleting'.tr(namedArgs: {'error': error});
  static String get menuItemEditorUnsavedChanges => 'menu_item_editor.unsaved_changes'.tr();
  static String get menuItemEditorUnsavedChangesMessage => 'menu_item_editor.unsaved_changes_message'.tr();
  static String get menuItemEditorStay => 'menu_item_editor.stay'.tr();
  static String get menuItemEditorLeave => 'menu_item_editor.leave'.tr();
  static String menuItemEditorErrorSaving(String error) => 'menu_item_editor.error_saving'.tr(namedArgs: {'error': error});
  static String get menuItemEditorSelectCategoryModal => 'menu_item_editor.select_category_modal'.tr();
  static String get menuItemEditorAddCategory => 'menu_item_editor.add_category'.tr();
  static String get menuItemEditorSelectOptionGroupsModal => 'menu_item_editor.select_option_groups_modal'.tr();
  static String menuItemEditorRequiredGroup(String description) => 'menu_item_editor.required_group'.tr(namedArgs: {'description': description});
  static String menuItemEditorOptionalGroup(String description) => 'menu_item_editor.optional_group'.tr(namedArgs: {'description': description});
  static String get menuItemEditorCreateNewOptionGroup => 'menu_item_editor.create_new_option_group'.tr();
  static String get menuItemEditorDone => 'menu_item_editor.done'.tr();
}