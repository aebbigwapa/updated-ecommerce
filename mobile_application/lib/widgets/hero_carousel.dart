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
  final List<HeroSlide> _slides = [
    HeroSlide(
      title: 'New Collection',
      subtitle: 'Discover our latest arrivals',
      buttonText: 'Shop Now',
      gradient: LinearGradient(
        colors: [AppTheme.primaryLight, AppTheme.primaryDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    HeroSlide(
      title: 'Summer Sale',
      subtitle: 'Up to 50% off selected items',
      buttonText: 'Explore Deals',
      gradient: LinearGradient(
        colors: [Colors.orange.shade300, Colors.pink.shade300],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    HeroSlide(
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
      if (mounted) {
        _nextPage();
        _startAutoPlay();
      }
    });
  }

  void _nextPage() {
    setState(() {
      _currentPage = (_currentPage + 1) % _slides.length;
    });
    _pageController.animateToPage(
      _currentPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    setState(() {
      _currentPage = (_currentPage - 1 + _slides.length) % _slides.length;
    });
    _pageController.animateToPage(
      _currentPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      child: Stack(
        children: [
          // Carousel
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemCount: _slides.length,
            itemBuilder: (context, index) {
              return _buildSlide(_slides[index]);
            },
          ),
          
          // Navigation Arrows
          Positioned(
            left: AppTheme.md,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                onPressed: _previousPage,
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: AppTheme.white,
                  size: 24,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.3),
                  shape: const CircleBorder(),
                ),
              ),
            ),
          ),
          
          Positioned(
            right: AppTheme.md,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                onPressed: _nextPage,
                icon: const Icon(
                  Icons.arrow_forward_ios,
                  color: AppTheme.white,
                  size: 24,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.3),
                  shape: const CircleBorder(),
                ),
              ),
            ),
          ),
          
          // Page Indicators
          Positioned(
            bottom: AppTheme.md,
            left: 0,
            right: 0,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 12 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index 
                          ? AppTheme.white 
                          : AppTheme.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(HeroSlide slide) {
    return Container(
      decoration: BoxDecoration(
        gradient: slide.gradient,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              slide.title,
              style: const TextStyle(
                fontFamily: AppTheme.fontDisplay,
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: AppTheme.white,
                height: 1.2,
              ),
            ),
            const SizedBox(height: AppTheme.md),
            Text(
              slide.subtitle,
              style: const TextStyle(
                fontFamily: AppTheme.fontBody,
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: AppTheme.white,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppTheme.xl),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/shop');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.white,
                foregroundColor: AppTheme.primaryLight,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.xl,
                  vertical: AppTheme.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              child: Text(
                slide.buttonText,
                style: const TextStyle(
                  fontFamily: AppTheme.fontBody,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HeroSlide {
  final String title;
  final String subtitle;
  final String buttonText;
  final Gradient gradient;

  HeroSlide({
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.gradient,
  });
}
