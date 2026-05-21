import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/product', arguments: product.id),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image — fixed aspect ratio, no Expanded
            AspectRatio(
              aspectRatio: 1.0,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.radiusLg),
                  topRight: Radius.circular(AppTheme.radiusLg),
                ),
                child: product.imageUrl != null
                    ? Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imagePlaceholder(),
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : Container(
                                color: AppTheme.grayLight,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primaryLight,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                      )
                    : _imagePlaceholder(),
              ),
            ),

            // Info section — no Spacer, no fixed height
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Product name: 2-line clamp with ellipsis + tooltip on long-press
                  Tooltip(
                    message: product.name,
                    preferBelow: true,
                    triggerMode: TooltipTriggerMode.longPress,
                    child: Text(
                      product.name,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontBody,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (product.sellerName != null && product.sellerName!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      product.sellerName!,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontBody,
                        fontSize: 11,
                        color: AppTheme.textLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  // Price + stock badge row — overflow-safe
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (product.hasDiscount)
                              Text(
                                '₱${product.originalPrice?.toStringAsFixed(2) ?? ''}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textLight,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            Text(
                              '₱${product.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontBody,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      _StockBadge(stock: product.stock),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
        color: AppTheme.accentBeige,
        child: const Center(
          child: Icon(Icons.image_outlined, size: 36, color: AppTheme.textLight),
        ),
      );
}

class _StockBadge extends StatelessWidget {
  final int stock;
  const _StockBadge({required this.stock});

  @override
  Widget build(BuildContext context) {
    final inStock = stock > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: inStock
            ? AppTheme.primaryLight.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        inStock ? '$stock' : 'Out',
        style: TextStyle(
          fontFamily: AppTheme.fontBody,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: inStock ? AppTheme.primaryLight : Colors.red,
        ),
      ),
    );
  }
}
