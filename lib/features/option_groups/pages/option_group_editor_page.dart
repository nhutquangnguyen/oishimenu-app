import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../models/menu_options.dart';
import '../../../models/menu_item.dart';
import '../providers/option_group_provider.dart';
import '../utils/validation.dart';
import '../../../services/menu_option_service.dart';
import '../../menu/services/menu_service.dart';
import '../../auth/providers/auth_provider.dart';

/// Main editor page for creating and editing option groups
/// Implements the complete UI specification including validation, preview, etc.
class OptionGroupEditorPage extends ConsumerStatefulWidget {
  final String? optionGroupId; // null for creating new group

  const OptionGroupEditorPage({
    super.key,
    this.optionGroupId,
  });

  @override
  ConsumerState<OptionGroupEditorPage> createState() => _OptionGroupEditorPageState();
}

class _OptionGroupEditorPageState extends ConsumerState<OptionGroupEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Form state
  List<MenuOption> _options = [];
  bool _isRequired = false;
  bool _allowMultiple = false;
  int _minSelections = 0;
  int _maxSelections = 1;

  // UI state
  bool _isDirty = false;
  bool _showPreview = true;
  Map<String, String> _validationErrors = {};

  // Editing state
  OptionGroup? _originalGroup;

  // Menu item linking state
  List<MenuItem> _availableMenuItems = [];
  List<String> _linkedMenuItemIds = [];
  bool _isLoadingMenuItems = false;

  @override
  void initState() {
    super.initState();
    _loadOptionGroup();
    _loadMenuItems();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadOptionGroup() async {
    if (widget.optionGroupId == null) return;

    try {
      final service = ref.read(optionGroupServiceProvider);
      final groups = await service.getAllOptionGroups(includeUnavailableOptions: true);
      final group = groups.firstWhere(
        (g) => g.id == widget.optionGroupId,
        orElse: () => throw Exception('Option group not found'),
      );

      print('📥 Loading option group from database:');
      print('   group.minSelection: ${group.minSelection}');
      print('   group.maxSelection: ${group.maxSelection}');
      print('   group.isRequired: ${group.isRequired}');

      setState(() {
        // Create a deep copy to prevent shared object references
        _originalGroup = group.copyWith(
          options: group.options.map((option) => option.copyWith()).toList(),
        );
        _nameController.text = group.name;
        _descriptionController.text = group.description ?? '';
        _options = group.options.map((option) => option.copyWith()).toList();
        _isRequired = group.isRequired;
        _allowMultiple = group.maxSelection > 1;
        _minSelections = group.minSelection;
        _maxSelections = group.maxSelection;

        print('   Setting _allowMultiple to: $_allowMultiple (because ${group.maxSelection} > 1 = ${group.maxSelection > 1})');
        print('   Setting _maxSelections to: $_maxSelections');
      });
    } catch (e) {
      _showError('Không thể tải nhóm tùy chọn: $e');
    }
  }

  Future<void> _loadMenuItems() async {
    setState(() => _isLoadingMenuItems = true);
    try {
      final menuService = MenuService();
      final menuOptionService = MenuOptionService();
      final currentUser = ref.read(currentUserProvider);

      if (currentUser == null) return;

      // Load all menu items
      final menuItems = await menuService.getAllMenuItems(userId: currentUser.id);

      // If editing existing group, load linked menu items
      List<String> linkedIds = [];
      if (widget.optionGroupId != null) {
        linkedIds = await menuOptionService.getMenuItemsUsingOptionGroup(widget.optionGroupId!);
      }

      setState(() {
        _availableMenuItems = menuItems;
        _linkedMenuItemIds = linkedIds;
        _isLoadingMenuItems = false;
      });
    } catch (e) {
      setState(() => _isLoadingMenuItems = false);
      _showError('Không thể tải danh sách món ăn: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(optionGroupLoadingProvider);
    final error = ref.watch(optionGroupErrorProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.optionGroupId == null ? 'option_groups_editor.create_title'.tr() : 'option_groups_editor.edit_title'.tr()),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Always use pop to return to the previous page
            // This ensures the calling page receives the result properly
            context.pop();
          },
        ),
      ),
      body: Column(
        children: [
          // Error display
          if (error != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                  IconButton(
                    onPressed: () => ref.read(optionGroupErrorProvider.notifier).state = null,
                    icon: const Icon(Icons.close, size: 16),
                    color: Colors.red[700],
                  ),
                ],
              ),
            ),
          // Main content - single column with preview at bottom
          Expanded(
            child: _buildFormSection(),
          ),
          // Footer actions
          _buildFooterActions(isLoading),
        ],
      ),
    );
  }

  Widget _buildFormSection() {
    return Form(
      key: _formKey,
      onChanged: () => setState(() => _isDirty = true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Name field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  text: 'Name ',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(
                      text: '*',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'option_groups_editor.name_hint'.tr(),
                  errorText: _validationErrors['name'],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                maxLength: 80,
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) {
                    return 'Option group name is required';
                  }
                  if (value!.trim().length > 80) {
                    return 'Name must be 80 characters or less';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    _isDirty = true;
                  });
                  _validateForm();
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Options section
          _buildOptionsSection(),
          const SizedBox(height: 24),

          // Selection rules section
          _buildSelectionRulesSection(),
          const SizedBox(height: 24),

          // Linked menu items section
          _buildLinkedMenuItemsSection(),
          const SizedBox(height: 24),

          // Preview section
          _buildPreviewSection(),
          const SizedBox(height: 100), // Space for footer
        ],
      ),
    );
  }

  Widget _buildOptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Options',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),

        // Options list
        if (_options.isNotEmpty)
          ...(_options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: option.isAvailable ? null : Colors.grey[100],
                ),
                child: Row(
                  children: [
                    // Availability toggle
                    Switch(
                      value: option.isAvailable,
                      onChanged: (value) {
                        setState(() {
                          _options[index] = option.copyWith(isAvailable: value);
                          _isDirty = true;
                        });
                      },
                      activeTrackColor: Colors.green[200],
                      thumbColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.green[700];
                        }
                        return null;
                      }),
                    ),
                    const SizedBox(width: 12),
                    // Option details - tappable to edit
                    Expanded(
                      child: InkWell(
                        onTap: () => _editOption(index),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                option.name.isEmpty ? 'Tùy chọn ${index + 1}' : option.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: option.isAvailable ? Colors.black : Colors.grey[600],
                                  decoration: option.isAvailable ? null : TextDecoration.lineThrough,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (option.price > 0) ...[
                              const SizedBox(width: 8),
                              Text(
                                '+${option.price.toStringAsFixed(0)}đ',
                                style: TextStyle(
                                  color: option.isAvailable ? Colors.grey[600] : Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey[400],
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList()),

        // Add option button
        InkWell(
          onTap: _addNewOption,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Add an option',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionRulesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Make mandatory
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Make mandatory',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'When toggled on, customers will have to select at least one option from this option group.',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _isRequired,
              onChanged: (value) => setState(() {
                _isRequired = value;
                _computeSelectionRules();
                _validateForm();
              }),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Allow multiple selections
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Allow multiple selections',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'When toggled on, customers will be able to pick more than one option from this option group.',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _allowMultiple,
              onChanged: (value) => setState(() {
                _allowMultiple = value;
                // When enabling multiple selection, set a reasonable default max
                if (value && _maxSelections <= 1) {
                  // Set to at least 2, even if there's only 1 option now
                  // User can add more options later
                  _maxSelections = 2;
                }
                // When disabling multiple selection, reset to 1
                if (!value) {
                  _maxSelections = 1;
                }
                _computeSelectionRules();
                _validateForm();
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLinkedMenuItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Linked Menu Items',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (!_isLoadingMenuItems)
              TextButton.icon(
                onPressed: () {
                  print('🔗 Manage Links button pressed');
                  _showMenuItemLinkingModal();
                },
                icon: const Icon(Icons.link, size: 16),
                label: Text('option_groups_editor.manage_links_button'.tr()),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue[600],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Select which menu items will show this option group when customers order.',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),

        if (_isLoadingMenuItems)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_linkedMenuItemIds.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[50],
            ),
            child: Column(
              children: [
                Icon(Icons.link_off, color: Colors.grey[400], size: 32),
                const SizedBox(height: 8),
                Text(
                  'No menu items linked',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This option group won\'t appear when customers order',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.restaurant_menu, color: Colors.green[600], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${_linkedMenuItemIds.length} linked menu items',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _linkedMenuItemIds.map((itemId) {
                    final menuItem = _availableMenuItems.firstWhere(
                      (item) => item.id == itemId,
                      orElse: () => MenuItem(
                        id: itemId,
                        name: 'Unknown Item',
                        price: 0,
                        categoryName: 'Unknown',
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      ),
                    );
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Text(
                        menuItem.name,
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPreviewSection() {
    final groupName = _nameController.text.trim().isEmpty
        ? 'Option group name'
        : _nameController.text.trim();

    final selectionText = _isRequired
        ? (_allowMultiple ? 'Required, pick ${_minSelections} to ${_maxSelections}' : 'Required, pick 1')
        : (_allowMultiple ? 'Optional, pick up to ${_maxSelections}' : 'Optional, pick up to 1');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preview',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      groupName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    selectionText,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (_options.isNotEmpty) ...[
                const SizedBox(height: 16),
                // Options
                ...(_options.asMap().entries.map((entry) {
                  final index = entry.key;
                  final option = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[400]!),
                            borderRadius: BorderRadius.circular(_allowMultiple ? 4 : 10),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            option.name.isEmpty ? 'Option ${index + 1}' : option.name,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        if (option.price > 0)
                          Text(
                            '+${option.price.toStringAsFixed(0)}đ',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList()),
              ] else ...[
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'No options added yet',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooterActions(bool isLoading) {
    final hasName = _nameController.text.trim().isNotEmpty;
    final canSave = hasName && _isDirty && _validationErrors.isEmpty && !isLoading;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Delete button (only for existing groups)
            if (widget.optionGroupId != null) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: isLoading ? null : _showDeleteConfirmation,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Delete',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
            // Save button
            Expanded(
              flex: widget.optionGroupId != null ? 1 : 1,
              child: ElevatedButton(
                onPressed: canSave ? _handleSave : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Event handlers
  void _addNewOption() {
    _showOptionDialog();
  }

  void _editOption(int index) {
    _showOptionDialog(_options[index], index);
  }

  void _deleteOption(int index) {
    setState(() {
      _options.removeAt(index);
      _isDirty = true;
      _computeSelectionRules();
      _validateForm();
    });
  }

  void _reorderOptions(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final option = _options.removeAt(oldIndex);
      _options.insert(newIndex, option);
      _isDirty = true;
    });
  }

  void _computeSelectionRules() {
    final rules = OptionGroupValidation.computeSelectionRules(
      isRequired: _isRequired,
      allowMultiple: _allowMultiple,
      optionCount: _options.length,
      maxSelections: _allowMultiple ? _maxSelections : null,
    );

    setState(() {
      _minSelections = rules.min;
      _maxSelections = rules.max;
    });
  }

  Future<void> _validateForm() async {
    final group = _buildOptionGroup();
    final validation = OptionGroupValidation.validateOptionGroup(group);

    // Check for duplicate option group name
    final service = ref.read(optionGroupServiceProvider);
    final allGroups = await service.getAllOptionGroups();
    final isNameUnique = OptionGroupValidation.isGroupNameUnique(
      group.name,
      allGroups,
      excludeId: widget.optionGroupId,
    );

    final errors = Map<String, String>.from(validation.errors);
    if (!isNameUnique) {
      errors['name'] = 'DUPLICATE_GROUP_NAME';
    }

    setState(() {
      _validationErrors = errors;
    });
  }

  OptionGroup _buildOptionGroup() {
    print('📦 Building option group:');
    print('   _allowMultiple: $_allowMultiple');
    print('   _minSelections: $_minSelections');
    print('   _maxSelections: $_maxSelections');
    print('   _isRequired: $_isRequired');

    return OptionGroup(
      id: widget.optionGroupId ?? '',
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      minSelection: _minSelections,
      maxSelection: _maxSelections,
      options: _options,
      isRequired: _isRequired,
      displayOrder: _originalGroup?.displayOrder ?? 0,
      isActive: true,
      createdAt: _originalGroup?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _handleSave() async {
    print('💾 Save button clicked');
    if (!_formKey.currentState!.validate()) {
      print('❌ Form validation failed');
      return;
    }

    final group = _buildOptionGroup();
    final notifier = ref.read(optionGroupNotifierProvider.notifier);

    print('🚀 Starting save process for: ${group.name}');

    try {
      String? groupId;
      if (widget.optionGroupId == null) {
        // Create new option group
        print('➕ Creating new option group');
        groupId = await notifier.createOptionGroup(group);
        print('✅ Created with ID: $groupId');
      } else {
        // Update existing option group
        print('🔄 Updating existing option group');
        final success = await notifier.updateOptionGroup(group);
        groupId = success ? widget.optionGroupId : null;
        print('✅ Update result: $success');
      }

      if (groupId != null) {
        // Save all options and link them to the group
        print('💾 Saving options for group $groupId');
        await _saveOptionsForGroup(groupId);

        if (mounted) {
          print('✅ Showing success message and popping with groupId: $groupId');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.optionGroupId == null
                  ? 'Created option group "${group.name}" with ${_options.length} options'
                  : 'Updated "${group.name}" with ${_options.length} options'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate back with the option group ID
          print('🔙 Calling context.pop($groupId)');
          context.pop(groupId);
          print('✅ context.pop completed');
        }
      } else {
        print('❌ groupId is null, not saving');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('option_groups_editor.error_saving'.tr(namedArgs: {'error': e.toString()})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveOptionsForGroup(String groupId) async {
    print('🔄 Starting to save ${_options.length} options for group $groupId');
    final notifier = ref.read(optionGroupNotifierProvider.notifier);

    // Save each option and link it to the group
    for (int i = 0; i < _options.length; i++) {
      final option = _options[i];
      print('💾 Processing option ${i + 1}: "${option.name}" (price: \$${option.price})');

      // Create the option if it doesn't have an ID (new option)
      String? optionId = option.id.isEmpty ? null : option.id;
      print('📝 Option ID: ${optionId ?? "NEW"}');

      if (optionId == null) {
        // Create new option
        print('➕ Creating new option: ${option.name}');
        optionId = await notifier.createMenuOption(option);
        print('✅ Created option with ID: $optionId');
      } else {
        // Update existing option
        print('🔄 Updating existing option: ${option.name}');
        await notifier.updateMenuOption(option);
        print('✅ Updated option: ${option.name}');
      }

      // Link the option to the group
      if (optionId != null) {
        print('🔗 Linking option $optionId to group $groupId');
        final linked = await notifier.connectOptionToGroup(optionId, groupId);
        print('${linked ? '✅' : '❌'} Link result: $linked');
      } else {
        print('❌ Failed to create option: ${option.name}');
      }
    }
    print('🎉 Finished saving all options for group $groupId');
  }

  void _handleCancel() {
    if (_isDirty) {
      _showUnsavedChangesDialog();
    } else {
      Navigator.pop(context);
    }
  }

  void _showOptionDialog([MenuOption? option, int? index]) {
    final nameController = TextEditingController(text: option?.name ?? '');
    final priceController = TextEditingController(
      text: option?.price != null ? option!.price.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(option == null ? 'option_groups_editor.add_option_title'.tr() : 'option_groups_editor.edit_option_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'option_groups_editor.option_name_field'.tr(),
                hintText: 'option_groups_editor.option_name_hint'.tr(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              decoration: InputDecoration(
                labelText: 'option_groups_editor.option_price_field'.tr(),
                hintText: '0',
                suffixText: 'đ',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('option_groups_editor.cancel_button'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final priceText = priceController.text.trim();

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('option_groups_editor.option_name_required'.tr())),
                );
                return;
              }

              final price = double.tryParse(priceText) ?? 0.0;

              final newOption = MenuOption(
                id: option?.id ?? '', // Empty ID for new options
                name: name,
                price: price,
                isAvailable: option?.isAvailable ?? true, // Preserve availability status
                createdAt: option?.createdAt ?? DateTime.now(),
                updatedAt: DateTime.now(),
              );

              setState(() {
                if (index != null) {
                  // Edit existing option
                  _options[index] = newOption;
                } else {
                  // Add new option
                  _options.add(newOption);
                }
                _isDirty = true;
                _validateForm();
              });

              Navigator.pop(context);
            },
            child: Text(option == null ? 'option_groups_editor.add_button'.tr() : 'option_groups_editor.save_button'.tr()),
          ),
        ],
      ),
    );
  }

  void _showMenuItemLinkingModal() {
    print('🔧 _showMenuItemLinkingModal called');
    print('📋 Current _linkedMenuItemIds: $_linkedMenuItemIds');
    print('📋 Available menu items count: ${_availableMenuItems.length}');

    // Create a copy of current linked items for the modal
    List<String> tempLinkedIds = List.from(_linkedMenuItemIds);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, modalSetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text(
                        'Link Menu Items',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Select which menu items will show this option group when customers order them.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ),
                const SizedBox(height: 20),

                // Menu items list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _availableMenuItems.length,
                    itemBuilder: (context, index) {
                      final menuItem = _availableMenuItems[index];
                      final isLinked = tempLinkedIds.contains(menuItem.id);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                          color: isLinked ? Colors.blue[50] : Colors.white,
                        ),
                        child: CheckboxListTile(
                          title: Text(
                            menuItem.name,
                            style: TextStyle(
                              fontWeight: isLinked ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${menuItem.price.toStringAsFixed(0)}đ'),
                              Text(
                                menuItem.categoryName,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          value: isLinked,
                          onChanged: (value) {
                            modalSetState(() {
                              if (value == true) {
                                tempLinkedIds.add(menuItem.id);
                              } else {
                                tempLinkedIds.remove(menuItem.id);
                              }
                            });
                          },
                          activeColor: Colors.blue[600],
                          controlAffinity: ListTileControlAffinity.trailing,
                        ),
                      );
                    },
                  ),
                ),

                // Footer with action buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${tempLinkedIds.length} items selected',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('option_groups_editor.cancel_button'.tr()),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          print('💾 Save Links button pressed! tempLinkedIds: $tempLinkedIds');
                          // Save the changes
                          await _updateMenuItemLinks(tempLinkedIds);
                          print('✅ Save Links completed, closing modal');
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                        ),
                        child: Text('option_groups_editor.save_links_button'.tr()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _updateMenuItemLinks(List<String> newLinkedIds) async {
    print('🚀 _updateMenuItemLinks called with newLinkedIds: $newLinkedIds');
    print('🏷️ Current optionGroupId: ${widget.optionGroupId}');

    setState(() => _isDirty = true);

    // If this is an existing option group, save the links immediately
    if (widget.optionGroupId != null) {
      try {
        final menuOptionService = MenuOptionService();

        // Keep track of the old linked IDs before updating the state
        final oldLinkedIds = List<String>.from(_linkedMenuItemIds);

        print('🔗 Updating menu item links for option group ${widget.optionGroupId}');
        print('📋 Old linked IDs: $oldLinkedIds');
        print('📋 New linked IDs: $newLinkedIds');

        // Remove existing links that are no longer needed
        for (final oldId in oldLinkedIds) {
          if (!newLinkedIds.contains(oldId)) {
            print('🗑️ Disconnecting menu item $oldId from option group ${widget.optionGroupId}');
            await menuOptionService.disconnectMenuItemFromOptionGroup(oldId, widget.optionGroupId!);
          }
        }

        // Add new links
        for (final newId in newLinkedIds) {
          if (!oldLinkedIds.contains(newId)) {
            print('🔗 Connecting menu item $newId to option group ${widget.optionGroupId}');
            await menuOptionService.connectMenuItemToOptionGroup(newId, widget.optionGroupId!);
          }
        }

        // Reload the linked menu items from database to ensure UI is in sync
        final updatedLinkedIds = await menuOptionService.getMenuItemsUsingOptionGroup(widget.optionGroupId!);

        // Update the UI state with the actual database state
        setState(() {
          _linkedMenuItemIds = updatedLinkedIds;
        });

        print('✅ Successfully updated menu item links. Final linked IDs: $updatedLinkedIds');
      } catch (e) {
        print('❌ Failed to update menu item links: $e');
        _showError('Failed to update menu item links: $e');
      }
    } else {
      // For new option groups, just update the UI state
      // The links will be saved when the option group is saved
      setState(() {
        _linkedMenuItemIds = newLinkedIds;
      });
    }
  }

  void _showDeleteConfirmation() {
    // TODO: Implement delete confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Delete confirmation - Coming soon!'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showUnsavedChangesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('option_groups_editor.unsaved_title'.tr()),
        content: Text('option_groups_editor.unsaved_message'.tr()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Future.microtask(() {
                if (mounted) context.go('/menu');
              });
            },
            child: Text('option_groups_editor.discard_button'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('option_groups_editor.cancel_button'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleSave();
            },
            child: Text('option_groups_editor.save_button'.tr()),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ref.read(optionGroupErrorProvider.notifier).state = message;
  }
}