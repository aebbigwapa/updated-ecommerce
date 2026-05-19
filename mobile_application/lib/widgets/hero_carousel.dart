import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HeroCarousel extends StatefulWidget {
  const HeroCarousel({super.key});

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_HeroSlide> _slides = [
    _HeroSlide(
      title: 'New Collection',
      subtitle: 'Discover our latest arrivals',
      buttonText: 'Shop Now',
      gradient: const LinearGradient(
        colors: [AppTheme.primaryLight, AppTheme.primaryDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    _HeroSlide(
      title: 'Summer Sale',
      subtitle: 'Up to 50% off selected items',
      buttonText: 'Explore Deals',
      gradient: LinearGradient(
        colors: [Colors.orange.shade300, Colors.pink.shade300],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    _HeroSlide(
      title: 'Premium Quality',
      subtitle: 'Fashion that defines you',
      buttonText: 'Learn More',
      gradient: LinearGradient(
        colors: [Colors.purple.shade300, AppTheme.primaryMid],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      _goTo((_currentPage + 1) % _slides.length);
      _startAutoPlay();
    });
  }

  void _goTo(int page) {
    setState(() => _currentPage = page);
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Responsive height: 40% of screen, clamped between 180–280px
    final screenHeight = MediaQuery.of(context).size.height;
    final carouselHeight = (screenHeight * 0.40).clamp(180.0, 280.0);

    return SizedBox(
      height: carouselHeight,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _slides.length,
            itemBuilder: (_, i) => _buildSlide(_slides[i], carouselHeight),
          ),

          // Left arrow
          Positioned(
            left: AppTheme.sm,
            top: 0,
            bottom: 0,
            child: Center(
              child: _ArrowBtn(
                icon: Icons.arrow_back_ios_new,
                onTap: () => _goTo((_currentPage - 1 + _slides.length) % _slides.length),
              ),
            ),
          ),

          // Right arrow
          Positioned(
            right: AppTheme.sm,
            top: 0,
            bottom: 0,
            child: Center(
              child: _ArrowBtn(
                icon: Icons.arrow_forward_ios,
                onTap: () => _goTo((_currentPage + 1) % _slides.length),
              ),
            ),
          ),

          // Dot indicators
          Positioned(
            bottom: AppTheme.sm,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentPage == i ? 14 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? AppTheme.white
                        : AppTheme.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(_HeroSlide slide, double height) {
    // Responsive font sizes based on carousel height
    final titleSize = (height * 0.13).clamp(20.0, 34.0);
    final subtitleSize = (height * 0.065).clamp(12.0, 16.0);

    return Container(
      decoration: BoxDecoration(gradient: slide.gradient),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.lg,
        vertical: AppTheme.md,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            slide.title,
            style: TextStyle(
              fontFamily: AppTheme.fontDisplay,
              fontSize: titleSize,
              fontWeight: FontWeight.w700,
              color: AppTheme.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            slide.subtitle,
            style: TextStyle(
              fontFamily: AppTheme.fontBody,
              fontSize: subtitleSize,
              color: AppTheme.white,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTheme.md),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/shop'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.white,
              foregroundColor: AppTheme.primaryLight,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.lg,
                vertical: AppTheme.sm,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              slide.buttonText,
              style: const TextStyle(
                fontFamily: AppTheme.fontBody,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrowBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppTheme.white, size: 16),
      ),
    );
  }
}

class _HeroSlide {
  final String title;
  final String subtitle;
  final String buttonText;
  final Gradient gradient;

  _HeroSlide({
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.gradient,
  });
}
