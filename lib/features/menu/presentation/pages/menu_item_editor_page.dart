import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../../models/menu_item.dart';
import '../../../../models/menu_options.dart';
import '../../services/menu_service.dart';
import '../../../../services/menu_option_service.dart';
import '../../../auth/providers/auth_provider.dart';

class MenuItemEditorPage extends ConsumerStatefulWidget {
  final String? menuItemId;
  final MenuItem? menuItem;

  const MenuItemEditorPage({
    super.key,
    this.menuItemId,
    this.menuItem,
  });

  @override
  ConsumerState<MenuItemEditorPage> createState() => _MenuItemEditorPageState();
}

class _MenuItemEditorPageState extends ConsumerState<MenuItemEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  final MenuService _menuService = MenuService();
  final MenuOptionService _optionService = MenuOptionService();
  final ImagePicker _picker = ImagePicker();

  List<String> _photos = [];
  String _selectedCategoryName = '';
  List<String> _selectedOptionGroupIds = [];
  List<OptionGroup> _availableOptionGroups = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = false;
  bool _isDirty = false;
  bool _originalAvailabilityStatus = true;
  DateTime? _originalCreatedAt;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupTextControllers();
  }

  void _setupTextControllers() {
    _nameController.addListener(() => setState(() => _isDirty = true));
    _descriptionController.addListener(() => setState(() => _isDirty = true));
    _priceController.addListener(() => setState(() => _isDirty = true));

    if (widget.menuItem != null) {
      _nameController.text = widget.menuItem!.name;
      _descriptionController.text = widget.menuItem!.description;
      _priceController.text = widget.menuItem!.price.toString();
      _photos = List<String>.from(widget.menuItem!.photos);
      _selectedCategoryName = widget.menuItem!.categoryName;
      // Option groups will be loaded separately as they're managed through relationships
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final optionGroups = await _optionService.getAllOptionGroups();
      final categories = await _menuService.getCategories();

      setState(() {
        _availableOptionGroups = optionGroups;
        _categories = categories.entries.map((e) => {
          'id': e.key,
          'name': e.value,
        }).toList();
      });

      // If we have a menuItemId, load the existing menu item data
      if (widget.menuItemId != null) {
        await _loadExistingMenuItem();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadExistingMenuItem() async {
    if (widget.menuItemId == null) return;

    try {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) return;

      final menuItems = await _menuService.getAllMenuItems(userId: currentUser.id);
      final menuItem = menuItems.firstWhere(
        (item) => item.id == widget.menuItemId,
        orElse: () => throw Exception('Menu item not found'),
      );

      // Load existing option groups for this menu item
      final existingOptionGroups = await _optionService.getOptionGroupsForMenuItem(menuItem.id);

      // Populate form fields with existing data
      _nameController.text = menuItem.name;
      _descriptionController.text = menuItem.description ?? '';
      _priceController.text = menuItem.price.toString();

      setState(() {
        _photos = List.from(menuItem.photos);
        _selectedCategoryName = menuItem.categoryName;
        _selectedOptionGroupIds = existingOptionGroups.map((group) => group.id).toList();
        _originalAvailabilityStatus = menuItem.availableStatus;
        _originalCreatedAt = menuItem.createdAt;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading existing menu item: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _handleCancel,
        ),
        title: Text(
          widget.menuItemId == null ? 'Add item' : 'Edit item',
          style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.grey),
            onPressed: () {
              // Show help dialog
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildItemNameSection(),
                    const SizedBox(height: 24),
                    _buildItemPhotoSection(),
                    const SizedBox(height: 24),
                    _buildDescriptionSection(),
                    const SizedBox(height: 24),
                    _buildCategorySection(),
                    const SizedBox(height: 24),
                    _buildPriceSection(),
                    const SizedBox(height: 24),
                    _buildOptionGroupsSection(),
                    const SizedBox(height: 32),
                    _buildDeleteButton(),
                    const SizedBox(height: 100), // Space for bottom button
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _buildBottomButton(),
    );
  }

  Widget _buildItemNameSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Item name',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Text(' *', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            hintText: 'Enter item name',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Item name is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildItemPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Item photo',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Main photo
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
                image: _photos.isNotEmpty ? _buildDecorationImage(_photos.first) : null,
              ),
              child: _photos.isEmpty
                  ? const Center(
                      child: Icon(Icons.image, color: Colors.grey, size: 32),
                    )
                  : Stack(
                      children: [
                        const Positioned(
                          top: 4,
                          left: 4,
                          child: Icon(Icons.drag_handle, color: Colors.white, size: 16),
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => _removePhoto(0),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.delete, color: Colors.white, size: 12),
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => _editPhoto(0),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.edit, color: Colors.white, size: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: 16),
            // Add photo placeholder
            GestureDetector(
              onTap: _addPhoto,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, color: Colors.grey, size: 24),
                    SizedBox(height: 4),
                    Icon(Icons.add, color: Colors.grey, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Max. 4 photos, up to 2 MB each.',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                maxLength: 300,
                decoration: const InputDecoration(
                  hintText: 'Enter description',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  counterText: '',
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${_descriptionController.text.length}/300',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Category',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Text(' *', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectCategory,
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
                    _selectedCategoryName.isEmpty ? 'Select a category' : _selectedCategoryName,
                    style: TextStyle(
                      color: _selectedCategoryName.isEmpty ? Colors.grey[600] : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Price',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Text(' *', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _priceController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            prefixText: 'đ ',
            hintText: '0',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Price is required';
            }
            if (double.tryParse(value) == null) {
              return 'Please enter a valid price';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildOptionGroupsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Option groups',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectOptionGroups,
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
                    _selectedOptionGroupIds.isEmpty
                        ? 'Select option groups'
                        : '${_selectedOptionGroupIds.length} selected',
                    style: TextStyle(
                      color: _selectedOptionGroupIds.isEmpty ? Colors.grey[600] : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
        if (_selectedOptionGroupIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _rearrangeOptionGroups,
            child: Text(
              'Rearrange option groups',
              style: TextStyle(color: Colors.blue[600], fontSize: 14),
            ),
          ),
        ],
      ],
    );
  }


  Widget _buildDeleteButton() {
    if (widget.menuItem == null) return const SizedBox();

    return Container(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: _deleteItem,
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        label: const Text(
          'Delete item',
          style: TextStyle(color: Colors.red, fontSize: 16),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
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
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _canSave() ? _handleSave : null,
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
              'Continue',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  bool _canSave() {
    return _nameController.text.trim().isNotEmpty &&
           _priceController.text.trim().isNotEmpty &&
           _selectedCategoryName.isNotEmpty;
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 4 photos allowed')),
      );
      return;
    }

    try {
      // Show image source selection
      final ImageSource? source = await _showImageSourceSelection();
      if (source == null) return;

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        // Save image to app documents directory
        final String savedPath = await _saveImageToAppDirectory(image);

        setState(() {
          _photos.add(savedPath);
          _isDirty = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding photo: $e')),
        );
      }
    }
  }

  Future<void> _editPhoto(int index) async {
    if (index >= _photos.length) return;

    try {
      // Show image source selection
      final ImageSource? source = await _showImageSourceSelection();
      if (source == null) return;

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        // Delete old image file if it exists
        final oldPath = _photos[index];
        if (oldPath.startsWith('/') && File(oldPath).existsSync()) {
          try {
            await File(oldPath).delete();
          } catch (e) {
            print('Error deleting old image: $e');
          }
        }

        // Save new image to app documents directory
        final String savedPath = await _saveImageToAppDirectory(image);

        setState(() {
          _photos[index] = savedPath;
          _isDirty = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating photo: $e')),
        );
      }
    }
  }

  Future<ImageSource?> _showImageSourceSelection() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Take Photo'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from Gallery'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.cancel),
            title: const Text('Cancel'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<String> _saveImageToAppDirectory(XFile image) async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String imagesDir = '${appDir.path}/menu_images';

    // Create images directory if it doesn't exist
    await Directory(imagesDir).create(recursive: true);

    // Generate unique filename
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String extension = image.path.split('.').last;
    final String fileName = 'menu_${timestamp}.$extension';
    final String savedPath = '$imagesDir/$fileName';

    // Copy image to app directory
    await File(image.path).copy(savedPath);

    return savedPath;
  }

  ImageProvider _getImageProvider(String imagePath) {
    // Check if it's a local file path
    if (imagePath.startsWith('/') && File(imagePath).existsSync()) {
      return FileImage(File(imagePath));
    }
    // Check if it's a network URL
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return NetworkImage(imagePath);
    }
    // Fallback - this shouldn't happen, but handle gracefully
    throw Exception('Invalid image path: $imagePath');
  }

  DecorationImage? _buildDecorationImage(String imagePath) {
    try {
      return DecorationImage(
        image: _getImageProvider(imagePath),
        fit: BoxFit.cover,
      );
    } catch (e) {
      print('Error loading image: $e');
      return null;
    }
  }

  Future<void> _removePhoto(int index) async {
    if (index >= _photos.length) return;

    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Photo'),
        content: const Text('Are you sure you want to remove this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final String photoPath = _photos[index];

      // Delete file if it's a local file
      if (photoPath.startsWith('/') && File(photoPath).existsSync()) {
        try {
          await File(photoPath).delete();
        } catch (e) {
          print('Error deleting photo file: $e');
        }
      }

      setState(() {
        _photos.removeAt(index);
        _isDirty = true;
      });
    }
  }

  void _improveDescription() {
    // TODO: Implement AI description improvement
    print('Improve description');
  }

  void _selectCategory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildCategorySelectionModal(),
    );
  }

  void _selectOptionGroups() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildOptionGroupSelectionModal(),
    );
  }

  void _rearrangeOptionGroups() {
    // TODO: Implement option group reordering
    print('Rearrange option groups');
  }

  void _deleteItem() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this menu item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performDelete();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete() async {
    if (widget.menuItem == null) return;

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to delete menu items'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _menuService.deleteMenuItem(widget.menuItem!.id, userId: currentUser.id);
      if (mounted) {
        context.go('/menu');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  void _handleCancel() {
    if (_isDirty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text('You have unsaved changes. Are you sure you want to leave?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Stay'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                // Use Future.microtask to ensure dialog is closed before navigating back
                Future.microtask(() {
                  if (mounted) context.go('/menu');
                });
              },
              child: const Text('Leave'),
            ),
          ],
        ),
      );
    } else {
      context.go('/menu');
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to save menu items'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final menuItem = MenuItem(
        id: widget.menuItemId ?? '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text),
        categoryName: _selectedCategoryName,
        photos: _photos,
        availableStatus: widget.menuItemId == null ? true : _originalAvailabilityStatus,
        createdAt: widget.menuItemId == null ? DateTime.now() : (_originalCreatedAt ?? DateTime.now()),
        updatedAt: DateTime.now(),
      );

      print('Save handler - widget.menuItemId is null: ${widget.menuItemId == null}');
      print('Save handler - menuItem.id: ${menuItem.id}');

      String savedMenuItemId;
      if (widget.menuItemId == null) {
        print('Taking CREATE path');
        final result = await _menuService.createMenuItem(menuItem, userId: currentUser.id);
        if (result == null) {
          throw Exception('Failed to create menu item');
        }
        savedMenuItemId = result;
        print('CREATE successful with ID: $result');
      } else {
        print('Taking UPDATE path');
        final success = await _menuService.updateMenuItem(menuItem, userId: currentUser.id);
        if (!success) {
          throw Exception('Failed to update menu item');
        }
        savedMenuItemId = widget.menuItemId!;
        print('UPDATE successful');
      }

      // Save option group relationships
      await _saveOptionGroupRelationships(savedMenuItemId);

      if (mounted) {
        context.go('/menu');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveOptionGroupRelationships(String menuItemId) async {
    try {
      // For updates, we need to clear existing relationships first
      if (widget.menuItemId != null) {
        final existingOptionGroups = await _optionService.getOptionGroupsForMenuItem(menuItemId);
        for (final optionGroup in existingOptionGroups) {
          await _optionService.disconnectMenuItemFromOptionGroup(menuItemId, optionGroup.id);
        }
      }

      // Connect the menu item to all selected option groups
      for (int i = 0; i < _selectedOptionGroupIds.length; i++) {
        final optionGroupId = _selectedOptionGroupIds[i];
        await _optionService.connectMenuItemToOptionGroup(
          menuItemId,
          optionGroupId,
          displayOrder: i,
        );
      }

      print('Successfully saved ${_selectedOptionGroupIds.length} option group relationships');
    } catch (e) {
      print('Error saving option group relationships: $e');
      // Don't throw - we want the menu item to be saved even if option groups fail
    }
  }

  Widget _buildCategorySelectionModal() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
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
          const Text(
            'Select a category',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                ..._categories.map((category) => RadioListTile<String>(
                  title: Text(category['name']),
                  value: category['name'],
                  groupValue: _selectedCategoryName,
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoryName = category['name'];
                      _isDirty = true;
                    });
                    Navigator.pop(context);
                  },
                  activeColor: Colors.green[600],
                )),
                const SizedBox(height: 20),
                ListTile(
                  leading: Icon(Icons.add, color: Colors.blue[600]),
                  title: Text(
                    'Add category',
                    style: TextStyle(color: Colors.blue[600]),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _addCategory();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionGroupSelectionModal() {
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
          const Text(
            'Select option groups',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ..._availableOptionGroups.map((group) => CheckboxListTile(
                  title: Text(group.name),
                  subtitle: Text(
                    group.isRequired
                        ? 'Required: ${group.description ?? ''}'
                        : 'Optional: ${group.description ?? ''}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  value: _selectedOptionGroupIds.contains(group.id),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedOptionGroupIds.add(group.id);
                      } else {
                        _selectedOptionGroupIds.remove(group.id);
                      }
                      _isDirty = true;
                    });
                  },
                  activeColor: Colors.green[600],
                  controlAffinity: ListTileControlAffinity.trailing,
                )),
                const SizedBox(height: 20),
                ListTile(
                  title: Text(
                    'Create a new option group',
                    style: TextStyle(color: Colors.blue[600]),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/menu/option-groups/new');
                  },
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Done'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addCategory() {
    // TODO: Implement add category functionality
  }
}