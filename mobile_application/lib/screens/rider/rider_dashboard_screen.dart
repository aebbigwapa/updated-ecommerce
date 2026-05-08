import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/realtime_service.dart';

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
  bool _isLoading = true;
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _initRealtime();
    _load();
  }

  Future<void> _initRealtime() async {
    final prefs = await SharedPreferences.getInstance();
    final riderId = prefs.getString('user_id');
    RealtimeService.instance.subscribeRiderOrders(riderId: riderId);
    _sub = RealtimeService.instance.ordersStream.listen((_) {
      if (mounted) { _load(); }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    RealtimeService.instance.unsubscribeOrders();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final user = await ApiService.getCurrentUser();
      if (user != null && mounted) { setState(() => _name = user['first_name'] ?? ''); }
      _token = await ApiService.getAuthToken() ?? '';
      final res = await ApiService.getRiderDashboard(_token);
      if (mounted) {
        setState(() {
          _stats = res;
          _deliveries = List<Map<String, dynamic>>.from(res['recent_deliveries'] ?? []);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) { setState(() => _isLoading = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeTab(name: _name, stats: _stats, deliveries: _deliveries, isLoading: _isLoading, onRefresh: _load),
      _DeliveriesTab(deliveries: _deliveries, isLoading: _isLoading, onRefresh: _load, token: _token),
      _EarningsTab(token: _token),
      const _ProfileTab(),
    ];
    return Scaffold(
      backgroundColor: AppTheme.grayLight,
      body: pages[_tab],
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
      (Icons.person_rounded, Icons.person_outlined, 'Profile'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(items.length, (i) {
              final active = i == current;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(active ? items[i].$1 : items[i].$2,
                          color: active ? AppTheme.primaryLight : AppTheme.textLight, size: 24),
                      const SizedBox(height: 2),
                      Text(items[i].$3,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                              color: active ? AppTheme.primaryLight : AppTheme.textLight)),
                    ],
                  ),
                ),
              );
            }),
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
class _HomeTab extends StatelessWidget {
  final String name;
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> deliveries;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  const _HomeTab({required this.name, required this.stats, required this.deliveries,
      required this.isLoading, required this.onRefresh});

  String _fmt(dynamic v) { try { return double.parse(v.toString()).toStringAsFixed(2); } catch (_) { return '0.00'; } }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : RefreshIndicator(
              onRefresh: onRefresh,
              child: CustomScrollView(slivers: [
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(children: [
                    const CircleAvatar(backgroundColor: Color(0xFF1a1a3e), child: Text('🏍️')),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Good day,', style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
                      Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                    ])),
                  ]),
                )),

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
                      Text('₱${_fmt(stats['total_earnings'])}',
                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(height: 16),
                      Row(children: [
                        _chip('Today', '₱${_fmt(stats['today_earnings'])}'),
                        const SizedBox(width: 8),
                        _chip('Week', '₱${_fmt(stats['week_earnings'])}'),
                        const SizedBox(width: 8),
                        _chip('Month', '₱${_fmt(stats['month_earnings'])}'),
                      ]),
                    ]),
                  ),
                )),

                // Stats row
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    _stat('${stats['total_deliveries'] ?? 0}', 'Total', Icons.local_shipping_outlined, Colors.blue),
                    const SizedBox(width: 10),
                    _stat('${stats['completed_deliveries'] ?? 0}', 'Done', Icons.check_circle_outline, Colors.green),
                    const SizedBox(width: 10),
                    _stat('${stats['active_deliveries'] ?? 0}', 'Active', Icons.sync_outlined, Colors.orange),
                    const SizedBox(width: 10),
                    _stat('₱${stats['rate_per_delivery'] ?? 50}', '/drop', Icons.monetization_on_outlined, AppTheme.primaryLight),
                  ]),
                )),

                // Map legend + map
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                    _DeliveryMap(deliveries: deliveries),
                  ]),
                )),

                // Recent deliveries
                const SliverToBoxAdapter(child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text('Recent Deliveries',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                )),
                deliveries.isEmpty
                    ? const SliverToBoxAdapter(child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('No deliveries yet', style: TextStyle(color: AppTheme.textLight)))))
                    : SliverList(delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _DeliveryTile(d: deliveries[i]),
                        childCount: deliveries.length > 5 ? 5 : deliveries.length,
                      )),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ]),
            ),
    );
  }

  Widget _legend(Color color, String label) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
  ]);

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

  Widget _stat(String val, String label, IconData icon, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.cardShadow),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textLight)),
      ]),
    ),
  );
}

// ── Deliveries Tab ────────────────────────────────────────────
class _DeliveriesTab extends StatelessWidget {
  final List<Map<String, dynamic>> deliveries;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final String token;
  const _DeliveriesTab({required this.deliveries, required this.isLoading, required this.onRefresh, required this.token});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : RefreshIndicator(
              onRefresh: onRefresh,
              child: deliveries.isEmpty
                  ? const Center(child: Text('No deliveries', style: TextStyle(color: AppTheme.textLight)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: deliveries.length,
                      itemBuilder: (ctx, i) => _DeliveryTile(
                        d: deliveries[i],
                        token: token,
                        onRefresh: onRefresh,
                        onTap: () => _showOrderMap(ctx, deliveries[i]),
                      ),
                    ),
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
        builder: (_, ctrl) => Column(children: [
          // Handle
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
              child: _DeliveryMap(deliveries: [d], height: 280),
            )
          else
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('No coordinates available for this order.',
                  style: TextStyle(color: AppTheme.textLight), textAlign: TextAlign.center),
            ),
          const SizedBox(height: 12),
          // Address info
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
    setState(() => _acting = true);
    final res = await ApiService.riderAcceptDelivery(widget.d['id'].toString(), widget.token!);
    if (mounted) {
      setState(() => _acting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? (res['success'] == true ? 'Accepted' : 'Failed'))),
      );
      if (res['success'] == true) widget.onRefresh?.call();
    }
  }

  Future<void> _markDelivered() async {
    if (_acting || widget.token == null) return;
    setState(() => _acting = true);
    final res = await ApiService.riderMarkDelivered(widget.d['id'].toString(), widget.token!);
    if (mounted) {
      setState(() => _acting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? (res['success'] == true ? 'Delivered' : 'Failed'))),
      );
      if (res['success'] == true) widget.onRefresh?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final id = (d['id'] ?? '').toString();
    final shortId = id.length >= 8 ? id.substring(0, 8) : id;
    final status = d['status']?.toString() ?? 'pending';
    final address = d['address']?.toString() ?? d['shipping_address']?.toString() ?? '';
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
            boxShadow: AppTheme.cardShadow),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.local_shipping_outlined, color: _statusColor(status), size: 22),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Order #$shortId', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (address.isNotEmpty)
                  Text(address, style: const TextStyle(fontSize: 11, color: AppTheme.textLight),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              _StatusBadge(status: status),
              if (widget.onTap != null) ...[
                const SizedBox(width: 6),
                const Icon(Icons.map_outlined, size: 16, color: AppTheme.textLight),
              ],
            ]),
            if (widget.token != null && (status == 'ready_for_pickup' || status == 'in_transit')) ...[
              const SizedBox(height: 10),
              Row(children: [
                if (status == 'ready_for_pickup')
                  Expanded(
                    child: _acting
                        ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                        : ElevatedButton.icon(
                            onPressed: _accept,
                            icon: const Icon(Icons.check, size: 14),
                            label: const Text('Accept', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                  ),
                if (status == 'in_transit')
                  Expanded(
                    child: _acting
                        ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                        : ElevatedButton.icon(
                            onPressed: _markDelivered,
                            icon: const Icon(Icons.done_all, size: 14),
                            label: const Text('Mark Delivered', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                  ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
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
    return SafeArea(
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(slivers: [
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
                const SliverToBoxAdapter(child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text('History', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                )),
                history.isEmpty
                    ? const SliverToBoxAdapter(child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('No earnings yet', style: TextStyle(color: AppTheme.textLight)))))
                    : SliverList(delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final e = history[i];
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
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();
  @override
  Widget build(BuildContext context) => const SafeArea(
      child: Center(child: Text('Profile', style: TextStyle(color: AppTheme.textLight))));
}
