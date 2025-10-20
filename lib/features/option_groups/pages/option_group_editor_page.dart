import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/menu_options.dart';
import '../providers/option_group_provider.dart';
import '../utils/validation.dart';

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

  @override
  void initState() {
    super.initState();
    _loadOptionGroup();
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
      final groups = await service.getAllOptionGroups();
      final group = groups.firstWhere(
        (g) => g.id == widget.optionGroupId,
        orElse: () => throw Exception('Option group not found'),
      );

      setState(() {
        _originalGroup = group;
        _nameController.text = group.name;
        _descriptionController.text = group.description ?? '';
        _options = List.from(group.options);
        _isRequired = group.isRequired;
        _allowMultiple = group.maxSelection > 1;
        _minSelections = group.minSelection;
        _maxSelections = group.maxSelection;
      });
    } catch (e) {
      _showError('Không thể tải nhóm tùy chọn: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(optionGroupLoadingProvider);
    final error = ref.watch(optionGroupErrorProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.optionGroupId == null ? 'Tạo nhóm tùy chọn' : 'Edit option group'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Check if we came from the menu tab
            final state = GoRouterState.of(context);
            final fromMenu = state.uri.queryParameters['from'] == 'menu';

            if (fromMenu) {
              // Navigate back to menu page and show Option Groups tab
              context.go('/menu?tab=1');
            } else {
              // Use default back navigation
              context.pop();
            }
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
                  hintText: 'e.g., Drink Toppings',
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

          // Translations section
          _buildTranslationsSection(),
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
              child: InkWell(
                onTap: () => _editOption(index),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option.name.isEmpty ? 'Tùy chọn ${index + 1}' : option.name,
                          style: const TextStyle(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (option.price > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '+${option.price.toStringAsFixed(0)}đ',
                          style: TextStyle(
                            color: Colors.grey[600],
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
                _computeSelectionRules();
                _validateForm();
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTranslationsSection() {
    return InkWell(
      onTap: () => _showTranslationsDialog(),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.translate, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Edit translations',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Some translations are unavailable. You can enter them manually.',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
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
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          // Delete button (only for existing groups)
          if (widget.optionGroupId != null)
            IconButton(
              onPressed: isLoading ? null : _showDeleteConfirmation,
              icon: const Icon(Icons.delete, color: Colors.red, size: 24),
            ),
          const Spacer(),
          // Save button
          GestureDetector(
            onTap: canSave ? _handleSave : null,
            child: Text(
              'Save',
              style: TextStyle(
                fontSize: 16,
                color: canSave ? Colors.blue : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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

  void _validateForm() {
    final group = _buildOptionGroup();
    final validation = OptionGroupValidation.validateOptionGroup(group);

    setState(() {
      _validationErrors = validation.errors;
    });
  }

  OptionGroup _buildOptionGroup() {
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
    if (!_formKey.currentState!.validate()) return;

    final group = _buildOptionGroup();
    final notifier = ref.read(optionGroupNotifierProvider.notifier);

    try {
      String? groupId;
      if (widget.optionGroupId == null) {
        // Create new option group
        groupId = await notifier.createOptionGroup(group);
      } else {
        // Update existing option group
        final success = await notifier.updateOptionGroup(group);
        groupId = success ? widget.optionGroupId : null;
      }

      if (groupId != null) {
        // Save all options and link them to the group
        await _saveOptionsForGroup(groupId);

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.optionGroupId == null
                  ? 'Created option group "${group.name}" with ${_options.length} options'
                  : 'Updated "${group.name}" with ${_options.length} options'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving option group: $e'),
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
        title: Text(option == null ? 'Add Option' : 'Edit Option'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Option Name *',
                hintText: 'e.g., Sương sáo',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Additional Price (VND)',
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final priceText = priceController.text.trim();

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Option name is required')),
                );
                return;
              }

              final price = double.tryParse(priceText) ?? 0.0;

              final newOption = MenuOption(
                id: option?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                name: name,
                price: price,
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
            child: Text(option == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _showTranslationsDialog() {
    // TODO: Implement translations dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Translations dialog - Coming soon!'),
        backgroundColor: Colors.orange,
      ),
    );
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
        title: const Text('Thay đổi chưa được lưu'),
        content: const Text('Bạn có muốn lưu thay đổi trước khi thoát?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close editor
            },
            child: const Text('Bỏ qua'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleSave();
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ref.read(optionGroupErrorProvider.notifier).state = message;
  }
}