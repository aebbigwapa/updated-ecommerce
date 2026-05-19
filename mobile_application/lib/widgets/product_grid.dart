import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/product.dart';
import 'product_card.dart';

class ProductGrid extends StatelessWidget {
  final String title;
  final List<Product> products;
  final String? viewAllRoute;
  final bool isLoading;

  const ProductGrid({
    super.key,
    required this.title,
    required this.products,
    this.viewAllRoute,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.md, AppTheme.lg, AppTheme.md, AppTheme.lg,
      ),
      color: AppTheme.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row — Expanded prevents right overflow
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontDisplay,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (viewAllRoute != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, viewAllRoute!),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      fontFamily: AppTheme.fontBody,
                      fontSize: 13,
                      color: AppTheme.primaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppTheme.md),

          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.xl),
                child: CircularProgressIndicator(color: AppTheme.primaryLight),
              ),
            )
          else if (products.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.xl),
                child: Column(
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        size: 48, color: AppTheme.textLight),
                    const SizedBox(height: AppTheme.sm),
                    const Text(
                      'No products found',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppTheme.textLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            // LayoutBuilder drives a responsive childAspectRatio
            LayoutBuilder(
              builder: (context, constraints) {
                // card width = (total - spacing) / 2
                final cardWidth = (constraints.maxWidth - AppTheme.sm) / 2;
                // image is square (cardWidth), info section ~110px
                final cardHeight = cardWidth + 110;
                final ratio = cardWidth / cardHeight;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppTheme.sm,
                    mainAxisSpacing: AppTheme.sm,
                    childAspectRatio: ratio,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) =>
                      ProductCard(product: products[index]),
                );
              },
            ),
        ],
      ),
    );
  }
}
