import 'package:flutter/material.dart';
import 'dart:io';
import '../../../../models/menu_item.dart';

class MenuItemCard extends StatelessWidget {
  final MenuItem menuItem;
  final String categoryName;
  final VoidCallback? onTap;
  final VoidCallback? onToggleAvailability;
  final VoidCallback? onDelete;

  const MenuItemCard({
    super.key,
    required this.menuItem,
    required this.categoryName,
    this.onTap,
    this.onToggleAvailability,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          child: Row(
            children: [
              // Product image or placeholder
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getCategoryColor(categoryName).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getCategoryColor(categoryName).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: _buildImage(),
                ),
              ),

              const SizedBox(width: 12),

              // Item details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Item name
                    Text(
                      menuItem.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: menuItem.availableStatus
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 2),

                    // Price
                    Text(
                      '${menuItem.price.toStringAsFixed(0)}đ',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),

              // Availability toggle
              Transform.scale(
                scale: 0.8,
                child: Switch.adaptive(
                  value: menuItem.availableStatus,
                  onChanged: (_) => onToggleAvailability?.call(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  activeTrackColor: Colors.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    // Check if the menu item has photos
    if (menuItem.photos.isNotEmpty) {
      final firstPhoto = menuItem.photos.first;

      // Check if it's a local file path
      if (firstPhoto.startsWith('/')) {
        final file = File(firstPhoto);
        if (file.existsSync()) {
          return Image.file(
            file,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildPlaceholderIcon();
            },
          );
        }
      }

      // Check if it's a network URL
      if (firstPhoto.startsWith('http://') || firstPhoto.startsWith('https://')) {
        return Image.network(
          firstPhoto,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholderIcon();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
        );
      }
    }

    // Fallback to category icon
    return _buildPlaceholderIcon();
  }

  Widget _buildPlaceholderIcon() {
    return Icon(
      _getCategoryIcon(categoryName),
      color: _getCategoryColor(categoryName),
      size: 24,
    );
  }

  Color _getCategoryColor(String category) {
    final lowerCategory = category.toLowerCase();
    switch (lowerCategory) {
      case 'appetizers':
      case 'món khai vị':
      case 'khai vị':
        return Colors.orange[600]!;
      case 'main course':
      case 'món chính':
      case 'chính':
        return Colors.red[600]!;
      case 'desserts':
      case 'tráng miệng':
      case 'dessert':
        return Colors.pink[600]!;
      case 'beverages':
      case 'đồ uống':
      case 'nước uống':
      case 'thức uống':
        return Colors.blue[600]!;
      case 'vietnamese specials':
      case 'đặc sản việt nam':
      case 'món việt':
        return Colors.green[600]!;
      case 'coffee':
      case 'cà phê':
      case 'cà phê - coffee':
        return Colors.brown[600]!;
      case 'combo':
      case 'combo nâng lượng':
      case 'combo trà chiều':
        return Colors.purple[600]!;
      case 'matcha':
        return Colors.lightGreen[600]!;
      case 'ưu đãi hôm nay':
      case 'món mới':
        return Colors.amber[600]!;
      case 'ẩm thực- xứ đài':
      case 'ẩm thực':
        return Colors.teal[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  IconData _getCategoryIcon(String category) {
    final lowerCategory = category.toLowerCase();
    switch (lowerCategory) {
      case 'appetizers':
      case 'món khai vị':
      case 'khai vị':
        return Icons.restaurant;
      case 'main course':
      case 'món chính':
      case 'chính':
        return Icons.dinner_dining;
      case 'desserts':
      case 'tráng miệng':
      case 'dessert':
        return Icons.cake;
      case 'beverages':
      case 'đồ uống':
      case 'nước uống':
      case 'thức uống':
        return Icons.local_drink;
      case 'vietnamese specials':
      case 'đặc sản việt nam':
      case 'món việt':
        return Icons.star;
      case 'coffee':
      case 'cà phê':
      case 'cà phê - coffee':
        return Icons.coffee;
      case 'combo':
      case 'combo nâng lượng':
      case 'combo trà chiều':
        return Icons.set_meal;
      case 'matcha':
        return Icons.eco;
      case 'ưu đãi hôm nay':
        return Icons.local_offer;
      case 'món mới':
        return Icons.new_releases;
      case 'ẩm thực- xứ đài':
      case 'ẩm thực':
        return Icons.food_bank;
      default:
        return Icons.fastfood;
    }
  }
}