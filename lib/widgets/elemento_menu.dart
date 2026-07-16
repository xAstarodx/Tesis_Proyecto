import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ElementoMenu extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onTap;
  const ElementoMenu({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [

                Hero(
                  tag: 'product_${item['producto_id']}',
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: AppTheme.backgroundColor,
                      border: Border.all(
                        color: AppTheme.dividerColor,
                        width: 1,
                      ),
                    ),
                    child: item['imagen_url'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              item['imagen_url'],
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              cacheWidth: 150,
                              cacheHeight: 150,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Icon(
                                    Icons.restaurant_menu,
                                    size: 32,
                                    color: AppTheme.primaryColor.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        : Center(
                            child: Icon(
                              item['icono'] ?? Icons.restaurant_menu,
                              size: 32,
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['nombre'],
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppTheme.accentGradient,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '\$${(item['precio'] as num).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Bs ${(item['precio_bs'] as num).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Icon(
                  Icons.chevron_right,
                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
