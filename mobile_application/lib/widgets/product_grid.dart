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
      padding: const EdgeInsets.all(AppTheme.xl),
      color: AppTheme.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: AppTheme.fontDisplay,
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              if (viewAllRoute != null)
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, viewAllRoute!);
                  },
                  child: Text(
                    'View All',
                    style: TextStyle(
                      color: AppTheme.primaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.lg),
          
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryLight,
              ),
            )
          else if (products.isEmpty)
            Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: AppTheme.textLight,
                  ),
                  const SizedBox(height: AppTheme.md),
                  Text(
                    'No products found',
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppTheme.textLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppTheme.md,
                mainAxisSpacing: AppTheme.md,
                childAspectRatio: 0.72,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return ProductCard(product: product);
              },
            ),
        ],
      ),
    );
  }
}
