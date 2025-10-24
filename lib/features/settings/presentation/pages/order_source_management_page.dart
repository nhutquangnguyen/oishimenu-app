import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../models/order_source.dart';
import '../../../../services/order_source_service.dart';

class OrderSourceManagementPage extends StatefulWidget {
  const OrderSourceManagementPage({super.key});

  @override
  State<OrderSourceManagementPage> createState() => _OrderSourceManagementPageState();
}

class _OrderSourceManagementPageState extends State<OrderSourceManagementPage> {
  final OrderSourceService _orderSourceService = OrderSourceService();
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
      // Initialize default sources if empty
      await _orderSourceService.initializeDefaultOrderSources();

      final sources = await _orderSourceService.getOrderSources();
      setState(() {
        _orderSources = sources;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading order sources: $e')),
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
          title: Text(isEdit ? 'Edit Order Source' : 'Add Order Source'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    hintText: 'e.g., Shopee, GrabFood',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Type
                DropdownButtonFormField<OrderSourceType>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type *',
                    border: OutlineInputBorder(),
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
                  decoration: const InputDecoration(
                    labelText: 'Icon *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'onsite', child: Text('On-site (Restaurant)')),
                    DropdownMenuItem(value: 'takeaway', child: Text('Takeaway (Bag)')),
                    DropdownMenuItem(value: 'shopee', child: Text('Shopee (Cart)')),
                    DropdownMenuItem(value: 'grabfood', child: Text('GrabFood (Delivery)')),
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
                  decoration: const InputDecoration(
                    labelText: 'Commission Rate (%)',
                    hintText: '0-100',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Requires Commission Input
                CheckboxListTile(
                  title: const Text('Requires Commission Input'),
                  subtitle: const Text('Ask for amount when checking out'),
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
                    decoration: const InputDecoration(
                      labelText: 'Input Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: CommissionInputType.beforeFee,
                        child: Text('Amount Before Fee'),
                      ),
                      DropdownMenuItem(
                        value: CommissionInputType.afterFee,
                        child: Text('Amount After Fee'),
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
                  title: const Text('Active'),
                  subtitle: const Text('Show in checkout screen'),
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
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name is required')),
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
                  if (isEdit) {
                    await _orderSourceService.updateOrderSource(newSource);
                  } else {
                    await _orderSourceService.createOrderSource(newSource);
                  }
                  Navigator.pop(context, true);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: Text(isEdit ? 'Update' : 'Add'),
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
        title: const Text('Delete Order Source'),
        content: Text('Are you sure you want to delete "${source.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _orderSourceService.deleteOrderSource(source.id);
        _loadOrderSources();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order source deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Source Management'),
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
                        'No order sources',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _showEditDialog(null),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Order Source'),
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
                            Text('Type: ${source.type.value}'),
                            if (source.commissionRate > 0)
                              Text('Commission: ${source.commissionRate}%'),
                            if (source.requiresCommissionInput)
                              Text(
                                'Input: ${source.commissionInputType == CommissionInputType.beforeFee ? 'Before Fee' : 'After Fee'}',
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
                                child: const Text(
                                  'Inactive',
                                  style: TextStyle(fontSize: 12),
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
