import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/realtime_service.dart';
import 'rider_profile_screen.dart';

// ignore_for_file: invalid_use_of_protected_member

// ── Constants ─────────────────────────────────────────────────
const _kPhilippines = LatLng(12.8797, 121.7740);
const _kBlue  = Color(0xFF1565C0);
const _kRed   = Color(0xFFC62828);
const _kOrange = Color(0xFFFF6F00);

class RiderDashboardScreen extends StatefulWidget {
  const RiderDashboardScreen({super.key});
  @override
  State<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen> {
  int _tab = 0;
  String _name = '';
  String _token = '';
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _deliveries = [];
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  StreamSubscription<void>? _sub;
  Timer? _debounce;

  // Global keys so tabs can be triggered to refresh from parent
  final _deliveriesKey = GlobalKey<_DeliveriesTabState>();
  final _homeKey = GlobalKey<_HomeTabState>();
  final _chatKey = GlobalKey<_ChatTabState>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _initRealtime() async {
    final prefs = await SharedPreferences.getInstance();
    final riderId = prefs.getString('user_id');
    RealtimeService.instance.subscribeRiderOrders(riderId: riderId);
    _sub = RealtimeService.instance.ordersStream.listen((_) {
      if (!mounted) return;
      // Debounce: wait 600ms after last event before refreshing
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 600), () {
        if (mounted) _onRealtimeUpdate();
      });
    });
  }

  void _onRealtimeUpdate() {
    // Refresh dashboard stats
    _load();
    // Also trigger deliveries tab refresh if it's mounted
    _deliveriesKey.currentState?.reload();
    // Also trigger home tab extras refresh
    _homeKey.currentState?.reloadExtras();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sub?.cancel();
    RealtimeService.instance.unsubscribeOrders();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _token = await ApiService.getAuthToken() ?? '';
      if (_token.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      // Init realtime once token is confirmed
      if (_sub == null) await _initRealtime();

      // Read name from SharedPreferences (already saved at login — no extra network call)
      final prefs = await SharedPreferences.getInstance();
      final firstName = prefs.getString('user_first_name') ?? '';
      if (mounted) setState(() => _name = firstName);

      final res = await ApiService.getRiderDashboard(_token);
      if (mounted) {
        setState(() {
          _stats = res;
          _deliveries = List<Map<String, dynamic>>.from(res['recent_deliveries'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[RiderDashboard] _load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeTab(key: _homeKey, name: _name, stats: _stats, deliveries: _deliveries, isLoading: _isLoading, onRefresh: _load, token: _token, onSwitchToDeliveries: () => setState(() => _tab = 1)),
      _DeliveriesTab(key: _deliveriesKey, isLoading: _isLoading, onRefresh: _load, token: _token),
      _EarningsTab(token: _token),
      _ChatTab(key: _chatKey, token: _token),
      const _ProfileTab(),
    ];
    return Scaffold(
      backgroundColor: AppTheme.grayLight,
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: _BottomNav(current: _tab, onTap: (i) => setState(() => _tab = i)),
    );
  }
}

// ── Bottom Nav ────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_rounded, Icons.home_outlined, 'Home'),
      (Icons.local_shipping_rounded, Icons.local_shipping_outlined, 'Deliveries'),
      (Icons.monetization_on_rounded, Icons.monetization_on_outlined, 'Earnings'),
      (Icons.chat_bubble_rounded, Icons.chat_bubble_outline_rounded, 'Chat'),
      (Icons.person_rounded, Icons.person_outlined, 'Profile'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: List.generate(items.length, (i) {
                final active = i == current;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(active ? items[i].$1 : items[i].$2,
                              color: active ? AppTheme.primaryLight : AppTheme.textLight, size: 22),
                          const SizedBox(height: 4),
                          Text(items[i].$3,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                                  color: active ? AppTheme.primaryLight : AppTheme.textLight)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared: Delivery Map Widget ───────────────────────────────
/// Shows seller (blue), buyer (red), rider live location (orange), and route.
class _DeliveryMap extends StatefulWidget {
  final List<Map<String, dynamic>> deliveries;
  final double height;
  const _DeliveryMap({required this.deliveries, this.height = 220});

  @override
  State<_DeliveryMap> createState() => _DeliveryMapState();
}

class _DeliveryMapState extends State<_DeliveryMap> {
  final _mapController = MapController();
  LatLng? _riderPos;
  StreamSubscription<Position>? _posSub;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _startLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return;
    }
    if (perm == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition();
    if (mounted) setState(() => _riderPos = LatLng(pos.latitude, pos.longitude));

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((p) {
      if (mounted) setState(() => _riderPos = LatLng(p.latitude, p.longitude));
    });
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    for (final d in widget.deliveries) {
      // Seller / pickup — blue pin
      final sLat = double.tryParse('${d['pickup_latitude'] ?? ''}');
      final sLng = double.tryParse('${d['pickup_longitude'] ?? ''}');
      if (sLat != null && sLng != null) {
        markers.add(_pinMarker(LatLng(sLat, sLng), _kBlue, Icons.store_rounded));
      }
      // Buyer / delivery — red pin
      final bLat = double.tryParse('${d['delivery_latitude'] ?? ''}');
      final bLng = double.tryParse('${d['delivery_longitude'] ?? ''}');
      if (bLat != null && bLng != null) {
        markers.add(_pinMarker(LatLng(bLat, bLng), _kRed, Icons.location_pin));
      }
    }
    // Rider live dot — orange
    if (_riderPos != null) {
      markers.add(Marker(
        point: _riderPos!,
        width: 20, height: 20,
        child: Container(
          decoration: BoxDecoration(
            color: _kOrange,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: _kOrange.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 2)],
          ),
        ),
      ));
    }
    return markers;
  }

  List<Polyline> _buildRoutes() {
    final lines = <Polyline>[];
    for (final d in widget.deliveries) {
      final sLat = double.tryParse('${d['pickup_latitude'] ?? ''}');
      final sLng = double.tryParse('${d['pickup_longitude'] ?? ''}');
      final bLat = double.tryParse('${d['delivery_latitude'] ?? ''}');
      final bLng = double.tryParse('${d['delivery_longitude'] ?? ''}');
      if (sLat == null || sLng == null || bLat == null || bLng == null) continue;

      final pts = <LatLng>[];
      if (_riderPos != null) pts.add(_riderPos!);
      pts.addAll([LatLng(sLat, sLng), LatLng(bLat, bLng)]);

      lines.add(Polyline(points: pts, color: _kOrange.withValues(alpha: 0.7), strokeWidth: 3,
          isDotted: true));
    }
    return lines;
  }

  LatLng _center() {
    if (_riderPos != null) return _riderPos!;
    for (final d in widget.deliveries) {
      final lat = double.tryParse('${d['delivery_latitude'] ?? ''}');
      final lng = double.tryParse('${d['delivery_longitude'] ?? ''}');
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return _kPhilippines;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: widget.height,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: _center(), initialZoom: 13),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.mobile_application',
            ),
            PolylineLayer(polylines: _buildRoutes()),
            MarkerLayer(markers: _buildMarkers()),
          ],
        ),
      ),
    );
  }
}

Marker _pinMarker(LatLng point, Color color, IconData icon) => Marker(
  point: point,
  width: 36, height: 36,
  child: Icon(icon, color: color, size: 36,
      shadows: const [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))]),
);

// ── Home Tab ──────────────────────────────────────────────────
class _HomeTab extends StatefulWidget {
  final String name;
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> deliveries;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final String token;
  final VoidCallback onSwitchToDeliveries;
  const _HomeTab({super.key, required this.name, required this.stats, required this.deliveries,
      required this.isLoading, required this.onRefresh, required this.token,
      required this.onSwitchToDeliveries});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  bool _isAvailable = true;
  Map<String, dynamic> _perf = {};
  List<Map<String, dynamic>> _notifs = [];
  int _unread = 0;
  bool _notifOpen = false;
  Map<String, dynamic> _earningsData = {};
  bool _loadingEarnings = false;

  @override
  void initState() {
    super.initState();
    if (widget.token.isNotEmpty) _loadExtras();
  }

  @override
  void didUpdateWidget(_HomeTab old) {
    super.didUpdateWidget(old);
    if (old.token != widget.token && widget.token.isNotEmpty) _loadExtras();
  }

  // Called by parent on realtime update
  void reloadExtras() => _loadExtras();

  Future<void> _loadExtras() async {
    if (widget.token.isEmpty) return;
    try {
      // Run all 4 requests in parallel
      final results = await Future.wait([
        ApiService.riderGetAvailability(widget.token),
        ApiService.riderGetPerformance(widget.token),
        ApiService.riderGetNotifications(widget.token),
        _fetchEarnings(),
      ]);
      if (!mounted) return;
      final avail = results[0] as Map<String, dynamic>;
      final perf  = results[1] as Map<String, dynamic>;
      final notif = results[2] as Map<String, dynamic>;
      final earnings = results[3] as Map<String, dynamic>;
      setState(() {
        _isAvailable = avail['is_available'] != false;
        _perf = perf;
        _notifs = List<Map<String, dynamic>>.from(notif['notifications'] ?? []);
        _unread = notif['unread_count'] is int ? notif['unread_count'] : 0;
        _earningsData = earnings;
        _loadingEarnings = false;
      });
      if (_unread > 0 && mounted) {
        final latest = _notifs.firstWhere((n) => n['is_read'] != true, orElse: () => {});
        if (latest.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(latest['title']?.toString() ?? 'New notification'),
            duration: const Duration(seconds: 3),
            backgroundColor: AppTheme.primaryLight,
          ));
        }
      }
    } catch (e) {
      debugPrint('[HomeTab] _loadExtras error: $e');
      if (mounted) setState(() => _loadingEarnings = false);
    }
  }

  Future<Map<String, dynamic>> _fetchEarnings() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiService.flaskBaseUrl}/api/rider/earnings'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 10));
      final body = jsonDecode(res.body);
      final data = body['data'];
      return data is Map<String, dynamic> ? data : (data is Map ? Map<String, dynamic>.from(data) : {});
    } catch (_) {
      return {};
    }
  }

  Future<void> _toggleAvailability() async {
    final next = !_isAvailable;
    setState(() => _isAvailable = next);
    await ApiService.riderSetAvailability(widget.token, next);
  }

  Future<void> _markAllRead() async {
    await ApiService.riderMarkNotifsRead(widget.token);
    setState(() {
      _unread = 0;
      for (final n in _notifs) n['is_read'] = true;
    });
  }

  String _fmt(dynamic v) { try { return double.parse(v.toString()).toStringAsFixed(2); } catch (_) { return '0.00'; } }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          widget.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
              : RefreshIndicator(
                  onRefresh: () async { await widget.onRefresh(); await _loadExtras(); },
                  child: CustomScrollView(slivers: [
                    // Topbar: availability toggle + notification bell
                    SliverToBoxAdapter(child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(children: [
                        const Spacer(),
                        // Availability toggle
                        GestureDetector(
                          onTap: _toggleAvailability,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _isAvailable ? Colors.green.shade50 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _isAvailable ? Colors.green : Colors.grey.shade400),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                  color: _isAvailable ? Colors.green : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(_isAvailable ? 'Online' : 'Offline',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                      color: _isAvailable ? Colors.green.shade700 : Colors.grey.shade600)),
                            ]),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Notification bell
                        GestureDetector(
                          onTap: () => setState(() => _notifOpen = !_notifOpen),
                          child: Stack(
                            children: [
                              const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.notifications_outlined, size: 26, color: AppTheme.textDark)),
                              if (_unread > 0)
                                Positioned(
                                  right: 0, top: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    child: Text('$_unread', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ]),
                    )),

                    // Welcome Banner — matches web rider-welcome-banner
                    SliverToBoxAdapter(child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFF1a1a3e),
                              radius: 22,
                              child: Text('🏍️', style: TextStyle(fontSize: 18)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Welcome back, ${widget.name}!',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                              const SizedBox(height: 4),
                              const Text('Ready to deliver today?',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
                            ])),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: widget.onSwitchToDeliveries,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryLight,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              child: const Text('View Deliveries →'),
                            ),
                          ],
                        ),
                      ),
                    )),

                    // Dashboard cards
                    SliverToBoxAdapter(child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(children: [
                        Row(children: [
                          _stat('${widget.stats['completed_deliveries'] ?? 0}', 'Today', Icons.local_shipping_outlined, Colors.blue),
                          const SizedBox(width: 8),
                          _stat('${widget.stats['available_orders'] ?? 0}', 'Available', Icons.inbox_outlined, Colors.purple),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          _stat('${widget.stats['active_deliveries'] ?? 0}', 'Active', Icons.sync_outlined, Colors.orange),
                          const SizedBox(width: 8),
                          _stat('${widget.stats['completed_deliveries'] ?? 0}', 'Delivered', Icons.check_circle_outline, Colors.green),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: _earningCard('Total Earnings', '₱${_fmt(_earningsData['total'] ?? widget.stats['total_earnings'])}', Icons.account_balance_wallet_rounded, Colors.teal)),
                          const SizedBox(width: 8),
                          Expanded(child: _earningCard('Today\'s Earnings', '₱${_fmt(_earningsData['today'] ?? widget.stats['today_earnings'])}', Icons.monetization_on_outlined, Colors.indigo)),
                        ]),
                      ]),
                    )),

                    // Performance card
                    SliverToBoxAdapter(child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: AppTheme.cardShadow),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('📊 Performance', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                          const SizedBox(height: 12),
                          Row(children: [
                            _perfTile(_perf['avg_rating'] != null ? '${_perf['avg_rating']} ⭐' : '—', 'Avg Rating'),
                            _perfTile('${_perf['total_deliveries'] ?? 0}', 'Total'),
                            _perfTile(_perf['acceptance_rate'] != null ? '${_perf['acceptance_rate']}%' : '—%', 'Accept Rate'),
                            _perfTile(_perf['late_percentage'] != null ? '${_perf['late_percentage']}%' : '—%', 'Late %'),
                          ]),
                        ]),
                      ),
                    )),

                    // Earnings Chart
                    SliverToBoxAdapter(child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: AppTheme.cardShadow),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('📈 Daily Earnings — Last 7 Days',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                          const SizedBox(height: 12),
                          _loadingEarnings
                              ? const SizedBox(height: 140, child: Center(child: CircularProgressIndicator(color: AppTheme.primaryLight)))
                              : _SimpleBarChart(data: List<Map<String, dynamic>>.from(_earningsData['chart'] ?? [])),
                        ]),
                      ),
                    )),

                    // Map
                    SliverToBoxAdapter(child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Text('Active Deliveries Map',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                          const Spacer(),
                          _legend(_kBlue, 'Store'),
                          const SizedBox(width: 10),
                          _legend(_kRed, 'Buyer'),
                          const SizedBox(width: 10),
                          _legend(_kOrange, 'You'),
                        ]),
                        const SizedBox(height: 8),
                        _DeliveryMap(deliveries: widget.deliveries),
                      ]),
                    )),

                    // Active Orders
                    const SliverToBoxAdapter(child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text('🔄 Active Orders',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                    )),
                    SliverToBoxAdapter(child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          ...widget.deliveries.where((d) => d['status'] != 'delivered').take(3).map((d) {
                            final id = (d['id'] ?? '').toString();
                            final shortId = id.length >= 8 ? id.substring(0, 8) : id;
                            final customer = d['customer_name']?.toString() ?? 'Unknown';
                            final total = '₱${_fmt(d['total_amount'] ?? 0)}';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: AppTheme.cardShadow),
                              child: Row(children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                                  child: Icon(Icons.local_shipping_rounded, color: Colors.blue.shade700, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('Order #$shortId', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                                  const SizedBox(height: 4),
                                  Text(customer, style: const TextStyle(fontSize: 12, color: AppTheme.textLight), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 6),
                                  Text(total, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.green)),
                                ])),
                                _StatusBadge(status: d['status']?.toString() ?? ''),
                              ]),
                            );
                          }).toList(),
                          if (widget.deliveries.where((d) => d['status'] != 'delivered').isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: Text('No active orders', style: TextStyle(color: AppTheme.textLight))),
                            ),
                        ],
                      ),
                    )),

                    // Recent Deliveries
                    const SliverToBoxAdapter(child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text('Recent Deliveries',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                    )),
                    SliverToBoxAdapter(child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          ...widget.deliveries.take(5).map((d) {
                            final id = (d['id'] ?? '').toString();
                            final shortId = id.length >= 8 ? id.substring(0, 8) : id;
                            final customer = d['customer_name']?.toString() ?? 'Unknown';
                            final earned = '₱${_fmt(d['delivery_fee'] ?? 0)}';
                            final rating = d['rating'] != null ? '${d['rating']} ⭐' : 'No rating';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: AppTheme.cardShadow),
                              child: Row(children: [
                                Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('#$shortId', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                                  const SizedBox(height: 4),
                                  Text(customer, style: const TextStyle(fontSize: 11, color: AppTheme.textLight), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ])),
                                Expanded(flex: 1, child: Text(earned, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.green))),
                                Expanded(flex: 1, child: Text(rating, style: const TextStyle(fontSize: 12, color: AppTheme.textDark), textAlign: TextAlign.right)),
                              ]),
                            );
                          }).toList(),
                          if (widget.deliveries.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: Text('No deliveries yet', style: TextStyle(color: AppTheme.textLight))),
                            ),
                        ],
                      ),
                    )),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ]),
                ),

          // Notification panel overlay
          if (_notifOpen)
            Positioned(
              top: 60, right: 12,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 300,
                  constraints: const BoxConstraints(maxHeight: 360),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                      child: Row(children: [
                        const Expanded(child: Text('Notifications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                        TextButton(
                          onPressed: _markAllRead,
                          child: const Text('Mark all read', style: TextStyle(fontSize: 11)),
                        ),
                        IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _notifOpen = false)),
                      ]),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: _notifs.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('No notifications', style: TextStyle(color: AppTheme.textLight)),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: _notifs.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final n = _notifs[i];
                                final isRead = n['is_read'] == true;
                                return Container(
                                  color: isRead ? Colors.transparent : Colors.blue.shade50,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(n['title']?.toString() ?? '',
                                        style: TextStyle(fontSize: 12, fontWeight: isRead ? FontWeight.w400 : FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text(n['message']?.toString() ?? '',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textLight), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  ]),
                                );
                              },
                            ),
                    ),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
  ]);

  Widget _stat(String val, String label, IconData icon, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: AppTheme.cardShadow),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textLight)),
      ]),
    ),
  );

  Widget _earningCard(String title, String amount, IconData icon, Color color) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14), boxShadow: AppTheme.cardShadow),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: Colors.white70, size: 22),
      const SizedBox(height: 12),
      Text(title, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      const SizedBox(height: 8),
      Text(amount, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
    ]),
  );

  Widget _perfTile(String val, String label) => Expanded(
    child: Column(children: [
      Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textLight), textAlign: TextAlign.center),
    ]),
  );
}

// ── Deliveries Tab ────────────────────────────────────────────
class _DeliveriesTab extends StatefulWidget {
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final String token;
  const _DeliveriesTab({super.key, required this.isLoading, required this.onRefresh, required this.token});

  @override
  State<_DeliveriesTab> createState() => _DeliveriesTabState();
}

class _DeliveriesTabState extends State<_DeliveriesTab> {
  String _filter = 'all';
  List<Map<String, dynamic>> _deliveries = [];
  bool _loading = true;

  static const _filters = [
    ('all', 'All'),
    ('ready_for_pickup', 'Ready'),
    ('in_transit', 'In Transit'),
    ('delivered', 'Delivered'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_DeliveriesTab old) {
    super.didUpdateWidget(old);
    if (old.token != widget.token && widget.token.isNotEmpty) _load();
  }

  // Called by parent on realtime update
  void reload() => _load();

  String _lastError = '';

  Future<void> _load() async {
    final token = widget.token.isNotEmpty
        ? widget.token
        : (await ApiService.getAuthToken() ?? '');
    if (token.isEmpty) {
      if (mounted) setState(() { _loading = false; _lastError = 'No auth token'; });
      return;
    }
    if (mounted) setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiService.flaskBaseUrl}/api/rider/deliveries'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));
      debugPrint('[DeliveriesTab] status=${res.statusCode} body=${res.body}');
      final body = jsonDecode(res.body);
      final data = body['data'];
      List<Map<String, dynamic>> list = [];
      if (data is Map && data['deliveries'] is List) {
        list = List<Map<String, dynamic>>.from(
            (data['deliveries'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
      }
      debugPrint('[DeliveriesTab] parsed ${list.length} deliveries');
      if (mounted) setState(() {
        _deliveries = list;
        _loading = false;
        _lastError = 'HTTP ${res.statusCode} — ${list.length} items. ${res.statusCode != 200 ? res.body : ""}';
      });
    } catch (e) {
      debugPrint('[DeliveriesTab] _load error: $e');
      if (mounted) setState(() { _loading = false; _lastError = 'Error: $e'; });
    }
  }

  List<Map<String, dynamic>> get _filtered => _filter == 'all'
      ? _deliveries
      : _deliveries.where((d) => d['status'] == _filter).toList();

  @override
  Widget build(BuildContext context) {
    final activeOrders = _deliveries.where((d) => ['ready_for_pickup', 'in_transit'].contains(d['status'])).toList();
    return SafeArea(
      child: Column(children: [
        // Header with Map View button
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Text('My Deliveries', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
              const Spacer(),
              if (activeOrders.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => _showAllOrdersMap(activeOrders),
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text('Map View', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLight,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
            ],
          ),
        ),
        // Filter tabs
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((f) {
                final active = _filter == f.$1;
                // count badge
                final count = f.$1 == 'all'
                    ? _deliveries.length
                    : _deliveries.where((d) => d['status'] == f.$1).length;
                return GestureDetector(
                  onTap: () => setState(() => _filter = f.$1),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: active ? AppTheme.primaryLight : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? AppTheme.primaryLight : Colors.grey.shade300),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(f.$2, style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: active ? Colors.white : AppTheme.textLight,
                      )),
                      if (count > 0) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: active ? Colors.white.withOpacity(0.3) : AppTheme.primaryLight.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$count', style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: active ? Colors.white : AppTheme.primaryLight,
                          )),
                        ),
                      ],
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _filtered.isEmpty
                      ? Center(
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.local_shipping_outlined, size: 48, color: AppTheme.textLight),
                            const SizedBox(height: 12),
                            Text(
                              _filter == 'all' ? 'No deliveries available' : 'No ${_filter.replaceAll('_', ' ')} deliveries',
                              style: const TextStyle(color: AppTheme.textLight),
                            ),
                            if (_lastError.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(_lastError, style: const TextStyle(fontSize: 10, color: Colors.red), textAlign: TextAlign.center),
                              ),
                            ],
                          ]),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, i) => _DeliveryTile(
                            d: _filtered[i],
                            token: widget.token,
                            onRefresh: _load,
                            onTap: () => _showOrderMap(ctx, _filtered[i]),
                          ),
                        ),
                ),
        ),
      ]),
    );
  }

  void _showAllOrdersMap(List<Map<String, dynamic>> activeOrders) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const Expanded(child: Text('All Active Deliveries Map',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textDark))),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _DeliveryMap(deliveries: activeOrders, height: double.infinity),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  void _showOrderMap(BuildContext context, Map<String, dynamic> d) {
    final id = (d['id'] ?? '').toString();
    final shortId = id.length >= 8 ? id.substring(0, 8) : id;
    final sLat = double.tryParse('${d['pickup_latitude'] ?? ''}');
    final sLng = double.tryParse('${d['pickup_longitude'] ?? ''}');
    final bLat = double.tryParse('${d['delivery_latitude'] ?? ''}');
    final bLng = double.tryParse('${d['delivery_longitude'] ?? ''}');
    final hasCoords = (sLat != null && sLng != null) || (bLat != null && bLng != null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: Text('Order #$shortId',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textDark))),
                _StatusBadge(status: d['status']?.toString() ?? ''),
              ]),
            ),
            const SizedBox(height: 12),
            if (hasCoords)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _DeliveryMap(deliveries: [d], height: 260),
              )
            else
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text('No coordinates available.', style: TextStyle(color: AppTheme.textLight), textAlign: TextAlign.center),
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: _AddrCard(color: _kBlue, icon: Icons.store_rounded, label: 'Store / Pickup',
                    address: d['pickup_address']?.toString() ?? d['store_name']?.toString() ?? '—')),
                const SizedBox(width: 10),
                Expanded(child: _AddrCard(color: _kRed, icon: Icons.location_pin, label: 'Buyer / Delivery',
                    address: d['address']?.toString() ?? '—')),
              ]),
            ),
            if (sLat != null && sLng != null && bLat != null && bLng != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  const Icon(Icons.straighten, size: 14, color: AppTheme.textLight),
                  const SizedBox(width: 4),
                  Text('Distance: ${_calcDist(sLat, sLng, bLat, bLng).toStringAsFixed(2)} km',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
                ]),
              ),
            ],
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  double _calcDist(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}

class _AddrCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final String address;
  const _AddrCard({required this.color, required this.icon, required this.label, required this.address});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        const SizedBox(height: 2),
        Text(address, style: const TextStyle(fontSize: 11, color: AppTheme.textDark), maxLines: 2,
            overflow: TextOverflow.ellipsis),
      ])),
    ]),
  );
}

// ── Delivery Tile ─────────────────────────────────────────────
class _DeliveryTile extends StatefulWidget {
  final Map<String, dynamic> d;
  final VoidCallback? onTap;
  final String? token;
  final Future<void> Function()? onRefresh;
  const _DeliveryTile({required this.d, this.onTap, this.token, this.onRefresh});

  @override
  State<_DeliveryTile> createState() => _DeliveryTileState();
}

class _DeliveryTileState extends State<_DeliveryTile> {
  bool _acting = false;

  Future<void> _accept() async {
    if (_acting || widget.token == null) return;
    // Confirm before accepting
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Accept Delivery'),
        content: Text('Accept order #${(widget.d['id']?.toString() ?? '').length >= 8 ? (widget.d['id']?.toString() ?? '').substring(0, 8).toUpperCase() : (widget.d['id']?.toString() ?? '').toUpperCase()}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _acting = true);
    try {
      final res = await ApiService.riderAcceptDelivery(widget.d['id'].toString(), widget.token!);
      if (mounted) {
        setState(() => _acting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['success'] == true ? 'Delivery accepted!' : (res['message']?.toString().isNotEmpty == true ? res['message'].toString() : 'Failed to accept. Order may no longer be available.')),
            backgroundColor: res['success'] == true ? Colors.teal : Colors.red,
          ),
        );
        if (res['success'] == true) widget.onRefresh?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _acting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _markDelivered() async {
    if (_acting || widget.token == null) return;
    // Show proof upload dialog first (matching web behaviour)
    await _showProofDialog();
  }

  Future<void> _showProofDialog() async {
    if (widget.token == null) return;
    final orderId = widget.d['id'].toString();
    await showDialog(
      context: context,
      builder: (ctx) => _ProofUploadDialog(
        orderId: orderId,
        token: widget.token!,
        onDone: () => widget.onRefresh?.call(),
      ),
    );
  }

  Future<void> _showDeclineModal({bool isReport = false}) async {
    if (widget.token == null) return;
    final reasons = await ApiService.riderGetDeclineReasons(widget.token!);
    final list = List<String>.from(isReport ? (reasons['report'] ?? []) : (reasons['decline'] ?? []));
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _DeclineReportSheet(
        orderId: widget.d['id'].toString(),
        token: widget.token!,
        isReport: isReport,
        reasons: list,
        onDone: () => widget.onRefresh?.call(),
      ),
    );
  }

  void _viewProof() {
    final url = widget.d['proof_of_delivery_url']?.toString() ?? '';
    if (url.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Proof of Delivery', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(16), child: Text('Could not load image'))),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final id = (d['id'] ?? '').toString();
    final shortId = id.length >= 8 ? id.substring(0, 8) : id;
    final status = d['status']?.toString() ?? 'pending';
    final address = d['address']?.toString() ?? '';
    final customer = d['customer_name']?.toString() ?? '';
    final payment = (d['payment_method']?.toString() ?? 'cod').toUpperCase();
    final hasProof = (d['proof_of_delivery_url']?.toString() ?? '').isNotEmpty;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: AppTheme.cardShadow),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.local_shipping_outlined, color: _statusColor(status), size: 22),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Order #$shortId', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              if (customer.isNotEmpty)
                Text(customer, style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
              if (address.isNotEmpty)
                Text(address, style: const TextStyle(fontSize: 11, color: AppTheme.textLight),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              _StatusBadge(status: status),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                child: Text(payment, style: TextStyle(fontSize: 9, color: Colors.blue.shade700, fontWeight: FontWeight.w600)),
              ),
            ]),
          ]),
          if (widget.token != null) ...[
            const SizedBox(height: 10),
            if (status == 'ready_for_pickup')
              Row(children: [
                Expanded(child: _actionBtn('Accept', Colors.teal, Icons.check, _acting ? null : _accept)),
                const SizedBox(width: 8),
                Expanded(child: _actionBtn('Decline', Colors.red.shade400, Icons.close, _acting ? null : () => _showDeclineModal())),
              ]),
            if (status == 'in_transit')
              Row(children: [
                Expanded(child: _actionBtn('Mark Delivered', Colors.green, Icons.done_all, _acting ? null : _markDelivered)),
                const SizedBox(width: 8),
                Expanded(child: _actionBtn('Report', Colors.orange, Icons.flag_outlined, _acting ? null : () => _showDeclineModal(isReport: true))),
              ]),
            if (status == 'delivered' && hasProof)
              _actionBtn('View Proof', Colors.indigo, Icons.photo_outlined, _viewProof),
          ],
          if (_acting)
            const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
        ]),
      ),
    );
  }

  Widget _actionBtn(String label, Color color, IconData icon, VoidCallback? onPressed) =>
      ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
}

// ── Proof Upload Dialog ─────────────────────────────────────────
class _ProofUploadDialog extends StatefulWidget {
  final String orderId;
  final String token;
  final VoidCallback onDone;
  const _ProofUploadDialog({required this.orderId, required this.token, required this.onDone});

  @override
  State<_ProofUploadDialog> createState() => _ProofUploadDialogState();
}

class _ProofUploadDialogState extends State<_ProofUploadDialog> {
  bool _uploading = false;
  File? _imageFile;
  final _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (picked != null && mounted) {
        setState(() => _imageFile = File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open ${source == ImageSource.camera ? "camera" : "gallery"}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _upload() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first')),
      );
      return;
    }
    setState(() => _uploading = true);
    try {
      final res = await ApiService.riderUploadProof(widget.orderId, widget.token, _imageFile!);
      if (!mounted) return;
      if (res['success'] == true) {
        final delivered = await ApiService.riderMarkDelivered(widget.orderId, widget.token);
        if (!mounted) return;
        Navigator.pop(context);
        widget.onDone();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(delivered['success'] == true ? 'Delivery completed!' : 'Proof uploaded but status update failed'),
          backgroundColor: delivered['success'] == true ? Colors.green : Colors.orange,
        ));
      } else {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['message']?.toString().isNotEmpty == true ? res['message'].toString() : 'Upload failed'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_uploading,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(children: [
                const Icon(Icons.camera_alt_outlined, color: AppTheme.primaryLight),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Proof of Delivery',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                ),
                if (!_uploading)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ]),
              const SizedBox(height: 4),
              const Text('Take or select a photo as proof before marking delivered.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
              const SizedBox(height: 16),

              // Image preview or placeholder
              GestureDetector(
                onTap: _uploading ? null : () => _pickImage(ImageSource.gallery),
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.file(_imageFile!, fit: BoxFit.cover, width: double.infinity),
                        )
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text('Tap to select from gallery', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        ]),
                ),
              ),
              const SizedBox(height: 12),

              // Camera / Gallery buttons
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploading ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: const Text('Camera', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploading ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library, size: 18),
                    label: const Text('Gallery', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              // Upload progress
              if (_uploading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                const Text('Uploading proof and updating status...', style: TextStyle(fontSize: 11, color: AppTheme.textLight), textAlign: TextAlign.center),
                const SizedBox(height: 8),
              ],

              // Mark as Delivered button
              ElevatedButton.icon(
                onPressed: (_imageFile == null || _uploading) ? null : _upload,
                icon: _uploading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.done_all, size: 18),
                label: Text(_uploading ? 'Processing...' : 'Mark as Delivered',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _imageFile != null ? Colors.green : Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Decline / Report Sheet ─────────────────────────────────────────
class _DeclineReportSheet extends StatefulWidget {
  final String orderId;
  final String token;
  final bool isReport;
  final List<String> reasons;
  final VoidCallback onDone;
  const _DeclineReportSheet({required this.orderId, required this.token, required this.isReport, required this.reasons, required this.onDone});

  @override
  State<_DeclineReportSheet> createState() => _DeclineReportSheetState();
}

class _DeclineReportSheetState extends State<_DeclineReportSheet> {
  String? _selected;
  final _noteCtrl = TextEditingController();
  bool _submitting = false;

  Future<void> _submit() async {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a reason')));
      return;
    }
    setState(() => _submitting = true);
    final res = widget.isReport
        ? await ApiService.riderReportIssue(widget.orderId, widget.token, _selected!, note: _noteCtrl.text.trim())
        : await ApiService.riderDeclineDelivery(widget.orderId, widget.token, _selected!, note: _noteCtrl.text.trim());
    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message']?.toString() ?? (res['success'] == true ? (widget.isReport ? 'Issue reported' : 'Order declined') : 'Failed')),
    ));
    if (res['success'] == true) widget.onDone();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Container(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(widget.isReport ? 'Report Issue' : 'Decline Order',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ]),
        Text('Select a reason:', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(height: 10),
        ...widget.reasons.map((r) => RadioListTile<String>(
          value: r,
          groupValue: _selected,
          title: Text(r, style: const TextStyle(fontSize: 13)),
          onChanged: (v) => setState(() => _selected = v),
          dense: true,
          contentPadding: EdgeInsets.zero,
        )),
        const SizedBox(height: 8),
        TextField(
          controller: _noteCtrl,
          decoration: const InputDecoration(labelText: 'Additional notes (optional)', border: OutlineInputBorder()),
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.isReport ? Colors.orange : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(widget.isReport ? 'Submit Report' : 'Decline Order'),
          ),
        ),
      ]),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(status.replaceAll('_', ' '),
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

Color _statusColor(String status) => const {
  'delivered': Colors.green, 'in_transit': Colors.blue,
  'ready_for_pickup': Colors.teal, 'pending': Colors.orange,
}[status] ?? Colors.grey;

// ── Earnings Tab ─────────────────────────────────────────────
class _EarningsTab extends StatefulWidget {
  final String token;
  const _EarningsTab({required this.token});
  @override
  State<_EarningsTab> createState() => _EarningsTabState();
}

class _EarningsTabState extends State<_EarningsTab> {
  Map<String, dynamic> _data = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_EarningsTab old) {
    super.didUpdateWidget(old);
    if (old.token != widget.token && widget.token.isNotEmpty) { _load(); }
  }

  Future<void> _load() async {
    if (widget.token.isEmpty) return;
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiService.flaskBaseUrl}/api/rider/earnings'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 10));
      final body = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
      final data = body['data'];
      if (mounted) {
        setState(() {
          _data = data is Map<String, dynamic> ? data : (data is Map ? Map<String, dynamic>.from(data) : {});
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) { setState(() => _loading = false); }
    }
  }

  String _fmt(dynamic v) { try { return double.parse(v.toString()).toStringAsFixed(2); } catch (_) { return '0.00'; } }

  @override
  Widget build(BuildContext context) {
    final history = List<Map<String, dynamic>>.from(_data['history'] ?? []);
    final todayEarnings = double.tryParse(_data['today']?.toString() ?? '0') ?? 0.0;
    const dailyGoal = 500.0;
    final goalPct = (todayEarnings / dailyGoal * 100).clamp(0, 100);
    
    // Calculate COD collected from history
    final codCollected = history
        .where((h) => (h['payment_method']?.toString() ?? 'cod').toLowerCase() == 'cod')
        .fold<double>(0.0, (sum, h) => sum + (double.tryParse(h['order_total']?.toString() ?? '0') ?? 0.0));

    return SafeArea(
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(slivers: [
                // Earnings card
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF1a1a3e), Color(0xFF2d2d6e)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Total Earnings', style: TextStyle(fontSize: 12, color: Colors.white60)),
                      const SizedBox(height: 4),
                      Text('₱${_fmt(_data['total'])}',
                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(height: 16),
                      Row(children: [
                        _chip('Today', '₱${_fmt(_data['today'])}'),
                        const SizedBox(width: 8),
                        _chip('Week', '₱${_fmt(_data['week'])}'),
                        const SizedBox(width: 8),
                        _chip('Month', '₱${_fmt(_data['month'])}'),
                      ]),
                    ]),
                  ),
                )),

                // Stats row
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    _statCard('${_data['deliveries'] ?? 0}', 'Total Deliveries', Icons.local_shipping_outlined, Colors.blue),
                    const SizedBox(width: 10),
                    _statCard('₱${_fmt(codCollected)}', 'COD Collected', Icons.payments_outlined, Colors.green),
                  ]),
                )),

                // Daily goal progress
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Daily Goal', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                        Text('₱${_fmt(todayEarnings)} / ₱${dailyGoal.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
                      ]),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: goalPct / 100,
                          minHeight: 10,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            goalPct >= 100 ? Colors.green : (goalPct >= 50 ? Colors.orange : AppTheme.primaryLight),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        goalPct >= 100 ? '🎉 Goal reached!' : (goalPct >= 50 ? 'More than halfway there!' : 'Keep going!'),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ]),
                  ),
                )),

                // Chart
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Daily Earnings — Last 7 Days',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                      const SizedBox(height: 12),
                      _SimpleBarChart(data: List<Map<String, dynamic>>.from(_data['chart'] ?? [])),
                    ]),
                  ),
                )),

                // History header
                const SliverToBoxAdapter(child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text('Earnings History', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                )),

                // History list
                history.isEmpty
                    ? const SliverToBoxAdapter(child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('No earnings yet', style: TextStyle(color: AppTheme.textLight)))))
                    : SliverList(delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final e = history[i];
                          final payment = (e['payment_method']?.toString() ?? 'cod').toUpperCase();
                          return Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                                boxShadow: AppTheme.cardShadow),
                            child: Row(children: [
                              const Icon(Icons.monetization_on_outlined, color: Colors.green, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Order #${e['order_id'] ?? ''}',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                Text(e['created_at']?.toString().substring(0, 10) ?? '',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
                                const SizedBox(height: 2),
                                Row(children: [
                                  Text('Order: ₱${_fmt(e['order_total'])}',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(payment,
                                        style: TextStyle(fontSize: 9, color: Colors.blue.shade700, fontWeight: FontWeight.w600)),
                                  ),
                                ]),
                              ])),
                              Text('₱${_fmt(e['amount'])}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.green, fontSize: 14)),
                            ]),
                          );
                        },
                        childCount: history.length,
                      )),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ]),
            ),
    );
  }

  Widget _chip(String label, String val) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white60)),
      ]),
    ),
  );

  Widget _statCard(String val, String label, IconData icon, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: AppTheme.cardShadow),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textLight), textAlign: TextAlign.center),
      ]),
    ),
  );
}

// ── Simple Bar Chart ──────────────────────────────────────────
class _SimpleBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _SimpleBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox(height: 100, child: Center(child: Text('No data', style: TextStyle(color: AppTheme.textLight))));
    final maxVal = data.map((d) => double.tryParse(d['value']?.toString() ?? '0') ?? 0.0).reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: data.map((d) {
          final val = double.tryParse(d['value']?.toString() ?? '0') ?? 0.0;
          final pct = maxVal > 0 ? (val / maxVal) : 0.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (val > 0)
                  Text('₱${val.toStringAsFixed(0)}', style: const TextStyle(fontSize: 9, color: AppTheme.textLight)),
                const SizedBox(height: 4),
                Container(
                  height: (pct * 100).clamp(4, 100),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withOpacity(0.8),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(d['label']?.toString() ?? '', style: const TextStyle(fontSize: 9, color: AppTheme.textLight)),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Chat Tab ─────────────────────────────────────────────────
class _ChatTab extends StatefulWidget {
  final String token;
  const _ChatTab({super.key, required this.token});
  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;
  String? _userId;
  StreamSubscription<Map<String, dynamic>>? _msgSub;

  @override
  void initState() {
    super.initState();
    if (widget.token.isNotEmpty) _init();
  }

  @override
  void didUpdateWidget(_ChatTab old) {
    super.didUpdateWidget(old);
    if (old.token != widget.token && widget.token.isNotEmpty) _init();
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    RealtimeService.instance.unsubscribeMessages();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id');
    if (_userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    await _load();
    RealtimeService.instance.subscribeConversations(userId: _userId!);
    _msgSub = RealtimeService.instance.messagesStream.listen((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    if (widget.token.isEmpty) return;
    try {
      final res = await http.get(
        Uri.parse('${ApiService.flaskBaseUrl}/messages/api/flutter/conversations'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        final list = data is List
            ? List<Map<String, dynamic>>.from(
                data.map((e) => Map<String, dynamic>.from(e as Map)))
            : <Map<String, dynamic>>[];
        setState(() { _conversations = list; _loading = false; });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Riders can start a chat with admin support or with a buyer from a delivery
  Future<void> _startAdminChat() async {
    try {
      final adminRes = await http.get(
        Uri.parse('${ApiService.flaskBaseUrl}/messages/api/admin-user-id'),
      ).timeout(const Duration(seconds: 10));
      final adminId = jsonDecode(adminRes.body)['admin_id']?.toString();
      if (adminId == null || !mounted) return;
      final res = await http.post(
        Uri.parse('${ApiService.flaskBaseUrl}/messages/api/flutter/conversations/start'),
        headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'},
        body: jsonEncode({'other_id': adminId}),
      ).timeout(const Duration(seconds: 10));
      if ((res.statusCode == 200 || res.statusCode == 201) && mounted) {
        final conv = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
        await Navigator.push(context, MaterialPageRoute(
          builder: (_) => _RiderChatScreen(
            convId: conv['id']?.toString() ?? '',
            otherName: 'Admin Support',
            otherRole: 'admin',
            token: widget.token,
          ),
        ));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start chat: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    try {
      final diff = DateTime.now().difference(DateTime.parse(iso));
      if (diff.inMinutes < 1) return 'now';
      if (diff.inHours < 1) return '${diff.inMinutes}m';
      if (diff.inDays < 1) return '${diff.inHours}h';
      return '${diff.inDays}d';
    } catch (_) { return ''; }
  }

  String _displayName(Map other) {
    final role = other['role']?.toString() ?? '';
    if (role == 'admin') return 'Admin Support';
    final name = '${other['first_name'] ?? ''} ${other['last_name'] ?? ''}'.trim();
    return name.isNotEmpty ? name : 'User';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                const Text(
                  'Messages',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                ),
                const Spacer(),
                // Contact Admin Support button
                ElevatedButton.icon(
                  onPressed: _startAdminChat,
                  icon: const Icon(Icons.support_agent, size: 16),
                  label: const Text('Support', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLight,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Body
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _conversations.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 80),
                              const Icon(Icons.chat_bubble_outline, size: 56, color: AppTheme.textLight),
                              const SizedBox(height: 12),
                              const Text(
                                'No conversations yet',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 15, color: AppTheme.textLight),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Tap Support to chat with admin',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: AppTheme.textLight),
                              ),
                            ],
                          )
                        : ListView.separated(
                            itemCount: _conversations.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                            itemBuilder: (_, i) {
                              final conv = _conversations[i];
                              final other = conv['other_user'] as Map? ?? {};
                              final name = _displayName(other);
                              final role = other['role']?.toString() ?? '';
                              final lastMsg = conv['last_message']?.toString() ?? '';
                              final unread = (conv['unread_count'] as num? ?? 0).toInt();
                              final pic = other['profile_picture']?.toString();
                              final time = _timeAgo(conv['updated_at']?.toString());

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.15),
                                  backgroundImage: pic != null && pic.isNotEmpty ? NetworkImage(pic) : null,
                                  child: pic == null || pic.isEmpty
                                      ? Text(
                                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                                          style: const TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.w700),
                                        )
                                      : null,
                                ),
                                title: Row(children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                  ),
                                  if (role.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    _RoleBadge(role: role),
                                  ],
                                ]),
                                subtitle: Text(
                                  lastMsg,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: unread > 0 ? AppTheme.textDark : AppTheme.textLight,
                                    fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(time, style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
                                    if (unread > 0) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: const BoxDecoration(
                                          color: AppTheme.primaryLight,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '$unread',
                                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => _RiderChatScreen(
                                        convId: conv['id']?.toString() ?? '',
                                        otherName: name,
                                        otherRole: role,
                                        token: widget.token,
                                      ),
                                    ),
                                  );
                                  _load();
                                },
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Role badge (rider-scoped) ─────────────────────────────────
class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  static const _bg = {
    'buyer': Color(0xFFE3F2FD), 'seller': Color(0xFFF3E5F5),
    'rider': Color(0xFFE8F5E9), 'admin': Color(0xFFFFF3E0),
  };
  static const _fg = {
    'buyer': Color(0xFF1565C0), 'seller': Color(0xFF6A1B9A),
    'rider': Color(0xFF2E7D32), 'admin': Color(0xFFE65100),
  };

  @override
  Widget build(BuildContext context) {
    if (role.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _bg[role] ?? const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _fg[role] ?? const Color(0xFF333333)),
      ),
    );
  }
}

// ── Rider Chat Screen (full thread) ──────────────────────────
class _RiderChatScreen extends StatefulWidget {
  final String convId;
  final String otherName;
  final String otherRole;
  final String token;
  const _RiderChatScreen({
    required this.convId,
    required this.otherName,
    required this.otherRole,
    required this.token,
  });
  @override
  State<_RiderChatScreen> createState() => _RiderChatScreenState();
}

class _RiderChatScreenState extends State<_RiderChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _myId;
  StreamSubscription<Map<String, dynamic>>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    RealtimeService.instance.unsubscribeMessages();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _myId = prefs.getString('user_id');
    await _loadMessages();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    RealtimeService.instance.subscribeMessages(convId: widget.convId);
    _realtimeSub = RealtimeService.instance.messagesStream.listen((record) async {
      if (!mounted) return;
      final senderId = record['sender_id']?.toString();
      Map<String, dynamic>? senderInfo;
      if (senderId != null) {
        try {
          final res = await ApiService.client
              .from('users')
              .select('id, first_name, last_name, role, profile_picture')
              .eq('id', senderId)
              .single();
          senderInfo = Map<String, dynamic>.from(res);
        } catch (_) {}
      }
      final enriched = Map<String, dynamic>.from(record);
      if (senderInfo != null) enriched['sender'] = senderInfo;
      if (mounted && !_messages.any((m) => m['id'] == enriched['id'])) {
        setState(() => _messages.add(enriched));
        _scrollToBottom();
      }
    });
  }

  Future<void> _loadMessages() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiService.flaskBaseUrl}/messages/api/flutter/conversations/${widget.convId}/messages'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        setState(() {
          _messages = data is List
              ? List<Map<String, dynamic>>.from(data.map((e) => Map<String, dynamic>.from(e as Map)))
              : [];
          _loading = false;
        });
        _scrollToBottom();
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _ctrl.clear();
    try {
      final res = await http.post(
        Uri.parse('${ApiService.flaskBaseUrl}/messages/api/flutter/conversations/${widget.convId}/messages'),
        headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'},
        body: jsonEncode({'content': text}),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 201 && mounted) {
        final msg = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
        setState(() => _messages.add(msg));
        _scrollToBottom();
      }
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Flexible(child: Text(widget.otherName, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          if (widget.otherRole.isNotEmpty) ...[
            const SizedBox(width: 8),
            _RoleBadge(role: widget.otherRole),
          ],
        ]),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 1,
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
              : _messages.isEmpty
                  ? const Center(
                      child: Text('No messages yet. Say hello!',
                          style: TextStyle(color: AppTheme.textLight)))
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _RiderMsgBubble(
                        msg: _messages[i],
                        isMe: _messages[i]['sender_id']?.toString() == _myId,
                      ),
                    ),
        ),
        _buildInput(),
      ]),
    );
  }

  Widget _buildInput() => Container(
        padding: EdgeInsets.only(
            left: 12, right: 8, top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8, offset: const Offset(0, -2))],
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              minLines: 1, maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(color: AppTheme.textLight),
                filled: true, fillColor: AppTheme.grayLight,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(color: AppTheme.primaryLight, shape: BoxShape.circle),
              child: _sending
                  ? const Padding(padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ]),
      );
}

// ── Message bubble ────────────────────────────────────────────
class _RiderMsgBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  const _RiderMsgBubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final content = msg['content']?.toString() ?? '';
    final sender = msg['sender'] as Map? ?? {};
    final role = sender['role']?.toString() ?? '';
    final senderName = '${sender['first_name'] ?? ''} ${sender['last_name'] ?? ''}'.trim();
    final time = _fmt(msg['created_at']?.toString());

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe && (senderName.isNotEmpty || role.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 3),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (senderName.isNotEmpty)
                    Text(senderName, style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textLight)),
                  if (senderName.isNotEmpty && role.isNotEmpty) const SizedBox(width: 4),
                  if (role.isNotEmpty) _RoleBadge(role: role),
                ]),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primaryLight : Colors.grey.shade100,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(content, style: TextStyle(
                    fontSize: 14, color: isMe ? Colors.white : AppTheme.textDark)),
                const SizedBox(height: 4),
                Text(time, style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white.withValues(alpha: 0.7) : AppTheme.textLight)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }
}

// ── Profile Tab ───────────────────────────────────────────────
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();
  @override
  Widget build(BuildContext context) => const RiderProfileScreen(embedded: true);
}
