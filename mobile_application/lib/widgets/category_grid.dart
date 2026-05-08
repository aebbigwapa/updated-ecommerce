import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CategoryGrid extends StatelessWidget {
  const CategoryGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = [
      Category(
        emoji: '👗',
        name: 'Dresses & Skirts',
        description: 'Elegant dresses and skirts for every occasion',
      ),
      Category(
        emoji: '👚',
        name: 'Tops & Blouses',
        description: 'Stylish tops and blouses for casual and formal wear',
      ),
      Category(
        emoji: '🏃‍♀️',
        name: 'Activewear & Yoga Pants',
        description: 'Comfortable activewear for your fitness journey',
      ),
      Category(
        emoji: '👙',
        name: 'Lingerie & Sleepwear',
        description: 'Intimate apparel and comfortable sleepwear',
      ),
      Category(
        emoji: '🧥',
        name: 'Jackets & Coats',
        description: 'Warm and stylish outerwear for all seasons',
      ),
      Category(
        emoji: '👠',
        name: 'Shoes & Accessories',
        description: 'Complete your look with shoes and accessories',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppTheme.xl),
      color: AppTheme.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shop by Category',
            style: const TextStyle(
              fontFamily: AppTheme.fontDisplay,
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: AppTheme.lg),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: AppTheme.md,
              mainAxisSpacing: AppTheme.md,
              mainAxisExtent: 110,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return _buildCategoryCard(context, category);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, Category category) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/shop',
          arguments: category.name,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(AppTheme.md),
        decoration: BoxDecoration(
          color: AppTheme.grayLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.subtleShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              category.emoji,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 4),
            Text(
              category.name,
              style: const TextStyle(
                fontFamily: AppTheme.fontBody,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class Category {
  final String emoji;
  final String name;
  final String description;

  Category({
    required this.emoji,
    required this.name,
    required this.description,
  });
}
