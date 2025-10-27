import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../models/menu_item.dart';
import '../../../../services/supabase_service.dart';
import '../../../auth/providers/auth_provider.dart';

class ScanMenuPage extends ConsumerStatefulWidget {
  const ScanMenuPage({super.key});

  @override
  ConsumerState<ScanMenuPage> createState() => _ScanMenuPageState();
}

class _ScanMenuPageState extends ConsumerState<ScanMenuPage> {
  final SupabaseMenuService _menuService = SupabaseMenuService();
  bool _isScanning = false;
  bool _isProcessing = false;
  String _scannedData = '';
  String _scanType = '';
  List<MenuItem> _extractedItems = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scan Menu',
          style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.grey),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildScanOptions(),
            const SizedBox(height: 24),
            if (_scannedData.isNotEmpty) ...[
              _buildScannedDataSection(),
              const SizedBox(height: 24),
            ],
            if (_extractedItems.isNotEmpty) ...[
              _buildExtractedItemsSection(),
              const SizedBox(height: 24),
            ],
            _buildManualInputSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildScanOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose scan method',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: [
            _buildScanOption(
              icon: Icons.qr_code_scanner,
              title: 'QR Code',
              subtitle: 'Scan menu QR codes',
              color: Colors.blue,
              onTap: () => _startQRScan(),
            ),
            _buildScanOption(
              icon: Icons.barcode_reader,
              title: 'Barcode',
              subtitle: 'Scan product barcodes',
              color: Colors.green,
              onTap: () => _startBarcodeScan(),
            ),
            _buildScanOption(
              icon: Icons.photo_camera,
              title: 'Photo Menu',
              subtitle: 'Extract text from photos',
              color: Colors.orange,
              onTap: () => _startPhotoScan(),
            ),
            _buildScanOption(
              icon: Icons.document_scanner,
              title: 'Document',
              subtitle: 'Scan menu documents',
              color: Colors.purple,
              onTap: () => _startDocumentScan(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScanOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannedDataSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getScanTypeIcon(),
                color: _getScanTypeColor(),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Scanned $_scanType',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_isProcessing)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(
              _scannedData,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _processScannedData,
                  icon: const Icon(Icons.analytics),
                  label: const Text('Process Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clearScannedData,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Extracted Menu Items',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              '${_extractedItems.length} items',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _extractedItems.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = _extractedItems[index];
            return _buildExtractedItemCard(item, index);
          },
        ),
        const SizedBox(height: 16),
        if (_extractedItems.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _importAllItems,
              icon: const Icon(Icons.download),
              label: Text('Import All Items (${_extractedItems.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExtractedItemCard(MenuItem item, int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'đ${item.price.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Category: ${item.categoryName}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          if (item.description?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              item.description!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _editExtractedItem(index),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _importSingleItem(item, index),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Import'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManualInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Manual Input',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[600]),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Paste menu data or enter manually',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Paste menu data here or enter manually...\n\nExample:\nPhở Bò - 65000\nBún Chả - 55000\nBánh Mì - 25000',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (value) {
                  setState(() => _scannedData = value);
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _scannedData.isNotEmpty ? _processManualInput : null,
                  icon: const Icon(Icons.analytics),
                  label: const Text('Process Manual Input'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getScanTypeIcon() {
    switch (_scanType.toLowerCase()) {
      case 'qr code':
        return Icons.qr_code;
      case 'barcode':
        return Icons.barcode_reader;
      case 'photo':
        return Icons.photo_camera;
      case 'document':
        return Icons.document_scanner;
      default:
        return Icons.scanner;
    }
  }

  Color _getScanTypeColor() {
    switch (_scanType.toLowerCase()) {
      case 'qr code':
        return Colors.blue;
      case 'barcode':
        return Colors.green;
      case 'photo':
        return Colors.orange;
      case 'document':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void _startQRScan() {
    setState(() {
      _isScanning = true;
      _scanType = 'QR Code';
    });

    // Simulate QR scan - in real implementation, use camera
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isScanning = false;
        _scannedData = '{"menu": [{"name": "Phở Bò", "price": 65000, "category": "Phở"}, {"name": "Bún Chả", "price": 55000, "category": "Bún"}]}';
      });
    });

    _showScanningDialog();
  }

  void _startBarcodeScan() {
    setState(() {
      _isScanning = true;
      _scanType = 'Barcode';
    });

    // Simulate barcode scan
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isScanning = false;
        _scannedData = '1234567890123'; // Sample barcode
      });
    });

    _showScanningDialog();
  }

  void _startPhotoScan() {
    setState(() {
      _isScanning = true;
      _scanType = 'Photo';
    });

    // Simulate photo text extraction
    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        _isScanning = false;
        _scannedData = '''MENU QUÁN PHỞ VIỆT
Phở Bò Tái - 65,000đ
Phở Bò Chín - 70,000đ
Phở Gà - 60,000đ
Bún Chả Hà Nội - 55,000đ
Bún Bò Huế - 50,000đ
Bánh Mì Thịt - 25,000đ
Chả Cá Lã Vọng - 85,000đ''';
      });
    });

    _showScanningDialog();
  }

  void _startDocumentScan() {
    setState(() {
      _isScanning = true;
      _scanType = 'Document';
    });

    // Simulate document scan
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isScanning = false;
        _scannedData = '''Vietnamese Restaurant Menu
Noodle Soups:
- Pho Bo (Beef Pho) - 65,000 VND
- Pho Ga (Chicken Pho) - 60,000 VND
- Bun Bo Hue - 50,000 VND

Rice Dishes:
- Com Tam - 45,000 VND
- Com Ga - 50,000 VND''';
      });
    });

    _showScanningDialog();
  }

  void _showScanningDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Scanning $_scanType...'),
            const SizedBox(height: 8),
            const Text(
              'Point your camera at the target',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _isScanning = false);
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    // Auto-close dialog when scanning completes
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isScanning == false) {
        Navigator.pop(context);
      }
    });
  }

  void _processScannedData() {
    setState(() => _isProcessing = true);

    // Simulate processing
    Future.delayed(const Duration(seconds: 2), () {
      final extractedItems = _parseScannedData(_scannedData);
      setState(() {
        _extractedItems = extractedItems;
        _isProcessing = false;
      });
    });
  }

  void _processManualInput() {
    setState(() => _isProcessing = true);

    Future.delayed(const Duration(milliseconds: 500), () {
      final extractedItems = _parseScannedData(_scannedData);
      setState(() {
        _extractedItems = extractedItems;
        _isProcessing = false;
      });
    });
  }

  List<MenuItem> _parseScannedData(String data) {
    final items = <MenuItem>[];

    try {
      // Try JSON format first
      if (data.trim().startsWith('{') || data.trim().startsWith('[')) {
        // Handle JSON format (simplified)
        items.add(MenuItem(
          id: '',
          name: 'Phở Bò',
          price: 65000,
          categoryName: 'Phở',
          description: 'Traditional Vietnamese beef noodle soup',
          availableStatus: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
        return items;
      }

      // Parse text format
      final lines = data.split('\n');
      String currentCategory = 'General';

      for (String line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;

        // Check if line is a category (contains colon or is all caps)
        if (line.endsWith(':') || (line.toUpperCase() == line && !line.contains('-') && !line.contains('đ'))) {
          currentCategory = line.replaceAll(':', '').trim();
          continue;
        }

        // Parse menu item line
        final match = RegExp(r'(.+?)\s*[-–]\s*([0-9,\.]+)').firstMatch(line);
        if (match != null) {
          final name = match.group(1)?.trim() ?? '';
          final priceStr = match.group(2)?.replaceAll(',', '').replaceAll('.', '') ?? '0';
          final price = double.tryParse(priceStr) ?? 0;

          if (name.isNotEmpty && price > 0) {
            items.add(MenuItem(
              id: '',
              name: name,
              price: price,
              categoryName: currentCategory,
              description: '',
              availableStatus: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ));
          }
        }
      }
    } catch (e) {
      print('Error parsing scanned data: $e');
    }

    return items;
  }

  void _clearScannedData() {
    setState(() {
      _scannedData = '';
      _scanType = '';
      _extractedItems.clear();
    });
  }

  void _editExtractedItem(int index) {
    // TODO: Open edit dialog for extracted item
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('scan_menu.edit_coming_soon'.tr())),
    );
  }

  Future<void> _importSingleItem(MenuItem item, int index) async {
    try {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to import menu items'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await _menuService.createMenuItem(item);
      // SupabaseMenuService createMenuItem doesn't return a result, success means no exception
      setState(() {
        _extractedItems.removeAt(index);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported "${item.name}" successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing "${item.name}": $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importAllItems() async {
    if (_extractedItems.isEmpty) return;

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to import menu items'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    int successCount = 0;
    int errorCount = 0;

    for (final item in _extractedItems) {
      try {
        await _menuService.createMenuItem(item);
        successCount++;
      } catch (e) {
        errorCount++;
      }
    }

    setState(() {
      _extractedItems.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import completed: $successCount successful, $errorCount failed'),
          backgroundColor: errorCount == 0 ? Colors.green : Colors.orange,
        ),
      );

      // Return to menu page
      Navigator.pop(context, true);
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan Menu Help'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Scan Methods:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• QR Code: Scan QR codes containing menu data'),
              Text('• Barcode: Scan product barcodes for inventory'),
              Text('• Photo Menu: Extract text from menu photos'),
              Text('• Document: Scan printed menu documents'),
              SizedBox(height: 16),
              Text(
                'Manual Input Format:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Item Name - Price'),
              Text('Example: Phở Bò - 65000'),
              SizedBox(height: 8),
              Text('Categories can be specified with colons:'),
              Text('Noodles:\nPhở Bò - 65000\nBún Chả - 55000'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}