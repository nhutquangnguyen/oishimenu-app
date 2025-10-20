import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/menu_option_service.dart';
import '../../../models/menu_options.dart';

// Service provider for option groups
final optionGroupServiceProvider = Provider<MenuOptionService>((ref) {
  return MenuOptionService();
});

// Option groups list provider - fetches all active option groups
final optionGroupsProvider = FutureProvider<List<OptionGroup>>((ref) async {
  final service = ref.watch(optionGroupServiceProvider);
  return service.getAllOptionGroups();
});

// Single option group provider with options
final optionGroupProvider = FutureProvider.family<OptionGroup?, String>((ref, groupId) async {
  final service = ref.watch(optionGroupServiceProvider);
  final groups = await service.getAllOptionGroups();
  return groups.firstWhere(
    (group) => group.id == groupId,
    orElse: () => throw Exception('Option group not found'),
  );
});

// Options for a specific group provider
final optionsForGroupProvider = FutureProvider.family<List<MenuOption>, String>((ref, groupId) async {
  final service = ref.watch(optionGroupServiceProvider);
  return service.getOptionsForGroup(groupId);
});

// All menu options provider (for selecting options to add to groups)
final allMenuOptionsProvider = FutureProvider<List<MenuOption>>((ref) async {
  final service = ref.watch(optionGroupServiceProvider);
  return service.getAllMenuOptions();
});

// Menu items using a specific option group
final menuItemsUsingGroupProvider = FutureProvider.family<List<String>, String>((ref, groupId) async {
  final service = ref.watch(optionGroupServiceProvider);
  return service.getMenuItemsUsingOptionGroup(groupId);
});

// Loading state for option group operations
final optionGroupLoadingProvider = StateProvider<bool>((ref) => false);

// Error state for option group operations
final optionGroupErrorProvider = StateProvider<String?>((ref) => null);

// Current editing option group state
final editingOptionGroupProvider = StateProvider<OptionGroup?>((ref) => null);

// Form validation errors
final optionGroupValidationErrorsProvider = StateProvider<Map<String, String>>((ref) => {});

// Async notifier for option group operations
class OptionGroupNotifier extends AsyncNotifier<List<OptionGroup>> {
  @override
  Future<List<OptionGroup>> build() async {
    final service = ref.read(optionGroupServiceProvider);
    return service.getAllOptionGroups();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(optionGroupServiceProvider);
      final groups = await service.getAllOptionGroups();
      state = AsyncValue.data(groups);
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  Future<String?> createOptionGroup(OptionGroup optionGroup) async {
    try {
      ref.read(optionGroupLoadingProvider.notifier).state = true;
      ref.read(optionGroupErrorProvider.notifier).state = null;

      final service = ref.read(optionGroupServiceProvider);
      final id = await service.createOptionGroup(optionGroup);

      if (id != null) {
        // Refresh the list
        await refresh();
        return id;
      } else {
        ref.read(optionGroupErrorProvider.notifier).state = 'Failed to create option group';
        return null;
      }
    } catch (error) {
      ref.read(optionGroupErrorProvider.notifier).state = 'Error: $error';
      return null;
    } finally {
      ref.read(optionGroupLoadingProvider.notifier).state = false;
    }
  }

  Future<bool> updateOptionGroup(OptionGroup optionGroup) async {
    try {
      ref.read(optionGroupLoadingProvider.notifier).state = true;
      ref.read(optionGroupErrorProvider.notifier).state = null;

      final service = ref.read(optionGroupServiceProvider);
      final success = await service.updateOptionGroup(optionGroup);

      if (success) {
        // Refresh the list
        await refresh();
        return true;
      } else {
        ref.read(optionGroupErrorProvider.notifier).state = 'Failed to update option group';
        return false;
      }
    } catch (error) {
      ref.read(optionGroupErrorProvider.notifier).state = 'Error: $error';
      return false;
    } finally {
      ref.read(optionGroupLoadingProvider.notifier).state = false;
    }
  }

  Future<String?> createMenuOption(MenuOption option) async {
    try {
      ref.read(optionGroupLoadingProvider.notifier).state = true;
      ref.read(optionGroupErrorProvider.notifier).state = null;

      final service = ref.read(optionGroupServiceProvider);
      final id = await service.createMenuOption(option);

      if (id != null) {
        // Invalidate related providers
        ref.invalidate(allMenuOptionsProvider);
        return id;
      } else {
        ref.read(optionGroupErrorProvider.notifier).state = 'Failed to create menu option';
        return null;
      }
    } catch (error) {
      ref.read(optionGroupErrorProvider.notifier).state = 'Error: $error';
      return null;
    } finally {
      ref.read(optionGroupLoadingProvider.notifier).state = false;
    }
  }

  Future<bool> updateMenuOption(MenuOption option) async {
    try {
      ref.read(optionGroupLoadingProvider.notifier).state = true;
      ref.read(optionGroupErrorProvider.notifier).state = null;

      final service = ref.read(optionGroupServiceProvider);
      final success = await service.updateMenuOption(option);

      if (success) {
        // Invalidate related providers
        ref.invalidate(allMenuOptionsProvider);
        await refresh();
        return true;
      } else {
        ref.read(optionGroupErrorProvider.notifier).state = 'Failed to update menu option';
        return false;
      }
    } catch (error) {
      ref.read(optionGroupErrorProvider.notifier).state = 'Error: $error';
      return false;
    } finally {
      ref.read(optionGroupLoadingProvider.notifier).state = false;
    }
  }

  Future<bool> connectOptionToGroup(String optionId, String groupId, {int displayOrder = 0}) async {
    try {
      ref.read(optionGroupLoadingProvider.notifier).state = true;
      ref.read(optionGroupErrorProvider.notifier).state = null;

      final service = ref.read(optionGroupServiceProvider);
      final success = await service.connectOptionToGroup(optionId, groupId, displayOrder: displayOrder);

      if (success) {
        // Invalidate related providers
        ref.invalidate(optionsForGroupProvider(groupId));
        await refresh();
        return true;
      } else {
        ref.read(optionGroupErrorProvider.notifier).state = 'Failed to connect option to group';
        return false;
      }
    } catch (error) {
      ref.read(optionGroupErrorProvider.notifier).state = 'Error: $error';
      return false;
    } finally {
      ref.read(optionGroupLoadingProvider.notifier).state = false;
    }
  }

  Future<bool> disconnectOptionFromGroup(String optionId, String groupId) async {
    try {
      ref.read(optionGroupLoadingProvider.notifier).state = true;
      ref.read(optionGroupErrorProvider.notifier).state = null;

      final service = ref.read(optionGroupServiceProvider);
      final success = await service.disconnectOptionFromGroup(optionId, groupId);

      if (success) {
        // Invalidate related providers
        ref.invalidate(optionsForGroupProvider(groupId));
        await refresh();
        return true;
      } else {
        ref.read(optionGroupErrorProvider.notifier).state = 'Failed to disconnect option from group';
        return false;
      }
    } catch (error) {
      ref.read(optionGroupErrorProvider.notifier).state = 'Error: $error';
      return false;
    } finally {
      ref.read(optionGroupLoadingProvider.notifier).state = false;
    }
  }

  Future<bool> deleteOptionGroup(String groupId) async {
    try {
      ref.read(optionGroupLoadingProvider.notifier).state = true;
      ref.read(optionGroupErrorProvider.notifier).state = null;

      final service = ref.read(optionGroupServiceProvider);
      final success = await service.deleteOptionGroup(groupId);

      if (success) {
        // Refresh the list to remove the deleted group
        await refresh();
        return true;
      } else {
        ref.read(optionGroupErrorProvider.notifier).state = 'Failed to delete option group';
        return false;
      }
    } catch (error) {
      ref.read(optionGroupErrorProvider.notifier).state = 'Error: $error';
      return false;
    } finally {
      ref.read(optionGroupLoadingProvider.notifier).state = false;
    }
  }
}

// Provider for the option group notifier
final optionGroupNotifierProvider = AsyncNotifierProvider<OptionGroupNotifier, List<OptionGroup>>(() {
  return OptionGroupNotifier();
});