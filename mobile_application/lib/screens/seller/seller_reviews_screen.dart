import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/realtime_service.dart';

class SellerReviewsScreen extends StatefulWidget {
  const SellerReviewsScreen({super.key});

  @override
  State<SellerReviewsScreen> createState() => _SellerReviewsScreenState();
}

class _SellerReviewsScreenState extends State<SellerReviewsScreen> {
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String _filter = 'all';
  StreamSubscription<void>? _reviewsSub;

  static const _filters = [
    {'key': 'all', 'label': 'All'},
    {'key': '5', 'label': '5 ⭐'},
    {'key': '4', 'label': '4 ⭐'},
    {'key': '3', 'label': '3 ⭐'},
    {'key': '2', 'label': '1-2 ⭐'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
    RealtimeService.instance.subscribeReviews();
    _reviewsSub = RealtimeService.instance.reviewsStream.listen((_) {
      if (mounted) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _reviewsSub?.cancel();
    RealtimeService.instance.unsubscribeReviews();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = true);
    if (silent && mounted) setState(() => _isSyncing = true);
    try {
      final token = await ApiService.getAuthToken();
      if (token == null) { if (mounted) setState(() { _isLoading = false; _isSyncing = false; }); return; }
      final res = await ApiService.get('/api/seller/reviews', token: token);
      final raw = res is List ? res : (res['reviews'] ?? []);
      final data = List<Map<String, dynamic>>.from(
          (raw as List).map((e) => Map<String, dynamic>.from(e as Map)));
      if (mounted) {
        setState(() {
          _reviews = data;
          _isLoading = false;
          _isSyncing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _isSyncing = false; });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _reviews;
    if (_filter == '2') return _reviews.where((r) => (r['rating'] as num? ?? 0) <= 2).toList();
    return _reviews.where((r) => r['rating'].toString() == _filter).toList();
  }

  double get _avgRating {
    if (_reviews.isEmpty) return 0;
    final sum = _reviews.fold<double>(0, (s, r) => s + (r['rating'] as num? ?? 0).toDouble());
    return sum / _reviews.length;
  }

  int get _fiveStars => _reviews.where((r) => (r['rating'] as num? ?? 0) == 5).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grayLight,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: const Text('Reviews & Ratings',
            style: TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryLight))),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  // Stats row
                  Container(
                    color: AppTheme.white,
                    padding: const EdgeInsets.all(AppTheme.md),
                    child: Row(
                      children: [
                        _statChip('Avg Rating', _avgRating > 0 ? _avgRating.toStringAsFixed(1) : '—', Icons.star, Colors.amber),
                        _statChip('Total', '${_reviews.length}', Icons.chat_bubble_outline, Colors.blue),
                        _statChip('5 Stars', '$_fiveStars', Icons.star, Colors.orange),
                      ],
                    ),
                  ),
                  // Filter tabs
                  Container(
                    color: AppTheme.white,
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.sm, vertical: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _filters.map((f) {
                          final isActive = _filter == f['key'];
                          return GestureDetector(
                            onTap: () => setState(() => _filter = f['key']!),
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: isActive ? AppTheme.primaryLight : AppTheme.grayLight,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(f['label']!,
                                  style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w600,
                                      color: isActive ? AppTheme.white : AppTheme.textDark)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _filtered.isEmpty
                        ? const Center(child: Text('No reviews yet.', style: TextStyle(color: AppTheme.textLight)))
                        : ListView.builder(
                            itemCount: _filtered.length,
                            padding: const EdgeInsets.all(AppTheme.md),
                            itemBuilder: (_, i) => _reviewCard(_filtered[i]),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statChip(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.grayLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textLight)),
          ],
        ),
      ),
    );
  }

  Widget _reviewCard(Map<String, dynamic> r) {
    final rating = (r['rating'] as num? ?? 0).toInt();
    final date = (r['created_at'] ?? '').toString().split('T')[0];
    final user = r['user'] as Map? ?? {};
    final name = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.sm),
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name.isNotEmpty ? name : 'Anonymous',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text('★' * rating + '☆' * (5 - rating),
                  style: const TextStyle(color: Colors.amber, fontSize: 14)),
            ],
          ),
          if ((r['comment'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(r['comment'].toString(), style: const TextStyle(fontSize: 13, color: AppTheme.textLight)),
          ],
          if (date.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(date, style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
          ],
        ],
      ),
    );
  }
}
