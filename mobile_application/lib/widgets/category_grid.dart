import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CategoryGrid extends StatelessWidget {
  const CategoryGrid({super.key});

  static const _categories = [
    _Category('👗', 'Dresses & Skirts'),
    _Category('👚', 'Tops & Blouses'),
    _Category('🏃‍♀️', 'Activewear & Yoga Pants'),
    _Category('👙', 'Lingerie & Sleepwear'),
    _Category('🧥', 'Jackets & Coats'),
    _Category('👠', 'Shoes & Accessories'),
  ];

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
          const Text(
            'Shop by Category',
            style: TextStyle(
              fontFamily: AppTheme.fontDisplay,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: AppTheme.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: AppTheme.sm,
              mainAxisSpacing: AppTheme.sm,
              // Let height be driven by width — square-ish cards
              childAspectRatio: 1.0,
            ),
            itemCount: _categories.length,
            itemBuilder: (context, index) =>
                _CategoryCard(category: _categories[index]),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final _Category category;
  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/shop',
        arguments: category.name,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.sm),
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
            // FittedBox ensures emoji never overflows
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  category.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              category.name,
              style: const TextStyle(
                fontFamily: AppTheme.fontBody,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
                height: 1.2,
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

class _Category {
  final String emoji;
  final String name;
  const _Category(this.emoji, this.name);
}
