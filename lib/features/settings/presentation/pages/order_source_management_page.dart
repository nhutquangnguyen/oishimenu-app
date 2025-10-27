import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../models/order_source.dart';
import '../../../../core/providers/supabase_providers.dart';

class OrderSourceManagementPage extends ConsumerStatefulWidget {
  const OrderSourceManagementPage({super.key});

  @override
  ConsumerState<OrderSourceManagementPage> createState() => _OrderSourceManagementPageState();
}

class _OrderSourceManagementPageState extends ConsumerState<OrderSourceManagementPage> {
  List<OrderSource> _orderSources = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrderSources();
  }

  Future<void> _loadOrderSources() async {
    setState(() => _isLoading = true);
    try {
      final orderSourceService = ref.read(supabaseOrderSourceServiceProvider);

      // Initialize default sources if empty
      await orderSourceService.initializeDefaultOrderSources();

      final sources = await orderSourceService.getOrderSources();
      setState(() {
        _orderSources = sources;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('settings_order_sources.error_loading'.tr(namedArgs: {'error': e.toString()}))),
        );
      }
    }
  }

  Future<void> _showEditDialog(OrderSource? orderSource) async {
    final isEdit = orderSource != null;

    final nameController = TextEditingController(text: orderSource?.name ?? '');
    final commissionController = TextEditingController(
      text: orderSource?.commissionRate.toString() ?? '0',
    );

    OrderSourceType selectedType = orderSource?.type ?? OrderSourceType.onsite;
    String selectedIconPath = orderSource?.iconPath ?? 'onsite';
    bool requiresCommissionInput = orderSource?.requiresCommissionInput ?? false;
    CommissionInputType commissionInputType = orderSource?.commissionInputType ?? CommissionInputType.afterFee;
    bool isActive = orderSource?.isActive ?? true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'settings_order_sources.edit_title'.tr() : 'settings_order_sources.add_title'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'settings_order_sources.name_field'.tr(),
                    hintText: 'settings_order_sources.name_hint'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Type
                DropdownButtonFormField<OrderSourceType>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: 'settings_order_sources.type_field'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  items: OrderSourceType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.value),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Icon Path
                DropdownButtonFormField<String>(
                  value: selectedIconPath,
                  decoration: InputDecoration(
                    labelText: 'settings_order_sources.icon_field'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: 'onsite', child: Text('settings_order_sources.icon_onsite'.tr())),
                    DropdownMenuItem(value: 'takeaway', child: Text('settings_order_sources.icon_takeaway'.tr())),
                    DropdownMenuItem(value: 'shopee', child: Text('settings_order_sources.icon_shopee'.tr())),
                    DropdownMenuItem(value: 'grabfood', child: Text('settings_order_sources.icon_grabfood'.tr())),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedIconPath = value);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Commission Rate
                TextField(
                  controller: commissionController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'settings_order_sources.commission_field'.tr(),
                    hintText: 'settings_order_sources.commission_hint'.tr(),
                    suffixText: '%',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Requires Commission Input
                CheckboxListTile(
                  title: Text('settings_order_sources.requires_input_title'.tr()),
                  subtitle: Text('settings_order_sources.requires_input_subtitle'.tr()),
                  value: requiresCommissionInput,
                  onChanged: (value) {
                    setDialogState(() => requiresCommissionInput = value ?? false);
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                // Commission Input Type (only if requires input)
                if (requiresCommissionInput) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<CommissionInputType>(
                    value: commissionInputType,
                    decoration: InputDecoration(
                      labelText: 'settings_order_sources.input_type_field'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: CommissionInputType.beforeFee,
                        child: Text('settings_order_sources.input_type_before'.tr()),
                      ),
                      DropdownMenuItem(
                        value: CommissionInputType.afterFee,
                        child: Text('settings_order_sources.input_type_after'.tr()),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => commissionInputType = value);
                      }
                    },
                  ),
                ],
                const SizedBox(height: 16),

                // Is Active
                CheckboxListTile(
                  title: Text('settings_order_sources.active_title'.tr()),
                  subtitle: Text('settings_order_sources.active_subtitle'.tr()),
                  value: isActive,
                  onChanged: (value) {
                    setDialogState(() => isActive = value ?? true);
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('settings_order_sources.cancel_button'.tr()),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('settings_order_sources.name_required'.tr())),
                  );
                  return;
                }

                final now = DateTime.now();
                final newSource = OrderSource(
                  id: orderSource?.id ?? '',
                  name: nameController.text.trim(),
                  iconPath: selectedIconPath,
                  type: selectedType,
                  commissionRate: double.tryParse(commissionController.text) ?? 0,
                  requiresCommissionInput: requiresCommissionInput,
                  commissionInputType: commissionInputType,
                  isActive: isActive,
                  createdAt: orderSource?.createdAt ?? now,
                  updatedAt: now,
                );

                try {
                  final orderSourceService = ref.read(supabaseOrderSourceServiceProvider);

                  if (isEdit) {
                    await orderSourceService.updateOrderSource(newSource);
                  } else {
                    await orderSourceService.createOrderSource(newSource);
                  }
                  Navigator.pop(context, true);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('settings_order_sources.error_saving'.tr(namedArgs: {'error': e.toString()}))),
                  );
                }
              },
              child: Text(isEdit ? 'settings_order_sources.update_button'.tr() : 'settings_order_sources.add_button'.tr()),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _loadOrderSources();
    }
  }

  Future<void> _deleteOrderSource(OrderSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settings_order_sources.delete_title'.tr()),
        content: Text('settings_order_sources.delete_message'.tr(namedArgs: {'name': source.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('settings_order_sources.cancel_button'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('settings_order_sources.delete_button'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final orderSourceService = ref.read(supabaseOrderSourceServiceProvider);
        await orderSourceService.deleteOrderSource(source.id);
        _loadOrderSources();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('settings_order_sources.delete_success'.tr())),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('settings_order_sources.error_deleting'.tr(namedArgs: {'error': e.toString()}))),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('settings_order_sources.page_title'.tr()),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orderSources.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.source_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'settings_order_sources.empty_state'.tr(),
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _showEditDialog(null),
                        icon: const Icon(Icons.add),
                        label: Text('settings_order_sources.add_button'.tr()),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orderSources.length,
                  itemBuilder: (context, index) {
                    final source = _orderSources[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: _buildSourceIcon(source),
                        title: Text(
                          source.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('settings_order_sources.type_label'.tr(namedArgs: {'type': source.type.value})),
                            if (source.commissionRate > 0)
                              Text('settings_order_sources.commission_label'.tr(namedArgs: {'rate': source.commissionRate.toString()})),
                            if (source.requiresCommissionInput)
                              Text(
                                'settings_order_sources.input_label'.tr(namedArgs: {'type': source.commissionInputType == CommissionInputType.beforeFee ? 'settings_order_sources.input_type_before'.tr() : 'settings_order_sources.input_type_after'.tr()}),
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!source.isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'settings_order_sources.inactive_label'.tr(),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showEditDialog(source),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteOrderSource(source),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
      floatingActionButton: _orderSources.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _showEditDialog(null),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildSourceIcon(OrderSource source) {
    IconData iconData;
    Color iconColor;

    switch (source.iconPath.toLowerCase()) {
      case 'onsite':
        iconData = Icons.restaurant;
        iconColor = Colors.teal;
        break;
      case 'takeaway':
        iconData = Icons.shopping_bag;
        iconColor = Colors.teal;
        break;
      case 'shopee':
        iconData = Icons.shopping_cart;
        iconColor = Colors.orange;
        break;
      case 'grabfood':
        iconData = Icons.delivery_dining;
        iconColor = Colors.green;
        break;
      default:
        iconData = Icons.store;
        iconColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: iconColor),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
