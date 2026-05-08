import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  
  const ProductCard({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/product',
          arguments: product.id,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppTheme.radiusLg),
                    topRight: Radius.circular(AppTheme.radiusLg),
                  ),
                  color: AppTheme.grayLight,
                ),
                child: product.imageUrl != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(AppTheme.radiusLg),
                          topRight: Radius.circular(AppTheme.radiusLg),
                        ),
                        child: Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppTheme.accentBeige,
                              child: const Icon(
                                Icons.image_outlined,
                                size: 48,
                                color: AppTheme.textLight,
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: AppTheme.grayLight,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.primaryLight,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : Container(
                        color: AppTheme.accentBeige,
                        child: const Icon(
                          Icons.image_outlined,
                          size: 48,
                          color: AppTheme.textLight,
                        ),
                      ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontBody,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTheme.xs),
                    Text(
                      product.sellerName ?? '',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontBody,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (product.hasDiscount)
                                Text(
                                  '₱${product.originalPrice?.toStringAsFixed(2) ?? ''}',
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontBody,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: AppTheme.textLight,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              Text(
                                '₱${product.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontBody,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (product.stock > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.xs,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLight.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            child: Text(
                              '${product.stock}',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontBody,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryLight,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.xs,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            child: const Text(
                              'Out',
                              style: TextStyle(
                                fontFamily: AppTheme.fontBody,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
