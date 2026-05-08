import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';

class RealtimeService {
  static final RealtimeService _instance = RealtimeService._();
  RealtimeService._();
  static RealtimeService get instance => _instance;

  RealtimeChannel? _ordersChannel;
  RealtimeChannel? _productsChannel;
  RealtimeChannel? _applicationsChannel;
  RealtimeChannel? _usersChannel;
  RealtimeChannel? _cartChannel;
  RealtimeChannel? _reviewsChannel;

  final _ordersController       = StreamController<void>.broadcast();
  final _productsController     = StreamController<void>.broadcast();
  final _applicationsController = StreamController<void>.broadcast();
  final _usersController        = StreamController<void>.broadcast();
  final _cartController         = StreamController<void>.broadcast();
  final _reviewsController      = StreamController<void>.broadcast();

  Stream<void> get ordersStream       => _ordersController.stream;
  Stream<void> get productsStream     => _productsController.stream;
  Stream<void> get applicationsStream => _applicationsController.stream;
  Stream<void> get usersStream        => _usersController.stream;
  Stream<void> get cartStream         => _cartController.stream;
  Stream<void> get reviewsStream      => _reviewsController.stream;

  void subscribeOrders({String? userId}) {
    _ordersChannel?.unsubscribe();
    _ordersChannel = ApiService.client
        .channel('orders_realtime_${userId ?? 'all'}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: userId != null
              ? PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'buyer_id', value: userId)
              : null,
          callback: (_) => _ordersController.add(null),
        )
        .subscribe();
  }

  /// Rider-specific: listens to all order changes where rider_id matches,
  /// AND unfiltered changes (catches new ready_for_pickup orders with no rider yet).
  void subscribeRiderOrders({String? riderId}) {
    _ordersChannel?.unsubscribe();
    // Listen to all order changes — rider needs to see new available orders too
    _ordersChannel = ApiService.client
        .channel('rider_orders_${riderId ?? 'all'}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (_) => _ordersController.add(null),
        )
        .subscribe();
  }

  void subscribeProducts({String? sellerId}) {
    _productsChannel?.unsubscribe();
    _productsChannel = ApiService.client
        .channel('products_realtime_${sellerId ?? 'all'}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'products',
          filter: sellerId != null
              ? PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'seller_id', value: sellerId)
              : null,
          callback: (_) => _productsController.add(null),
        )
        .subscribe();
  }

  void subscribeApplications() {
    _applicationsChannel?.unsubscribe();
    _applicationsChannel = ApiService.client
        .channel('applications_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'applications',
          callback: (_) => _applicationsController.add(null),
        )
        .subscribe();
  }

  void subscribeUsers() {
    _usersChannel?.unsubscribe();
    _usersChannel = ApiService.client
        .channel('users_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
          callback: (_) => _usersController.add(null),
        )
        .subscribe();
  }

  void subscribeCart({String? userId}) {
    _cartChannel?.unsubscribe();
    _cartChannel = ApiService.client
        .channel('cart_realtime_${userId ?? 'all'}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'cart_items',
          filter: userId != null
              ? PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId)
              : null,
          callback: (_) => _cartController.add(null),
        )
        .subscribe();
  }

  void subscribeReviews() {
    _reviewsChannel?.unsubscribe();
    _reviewsChannel = ApiService.client
        .channel('reviews_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reviews',
          callback: (_) => _reviewsController.add(null),
        )
        .subscribe();
  }

  void unsubscribeOrders()       { _ordersChannel?.unsubscribe();       _ordersChannel = null; }
  void unsubscribeProducts()     { _productsChannel?.unsubscribe();     _productsChannel = null; }
  void unsubscribeApplications() { _applicationsChannel?.unsubscribe(); _applicationsChannel = null; }
  void unsubscribeUsers()        { _usersChannel?.unsubscribe();        _usersChannel = null; }
  void unsubscribeCart()         { _cartChannel?.unsubscribe();         _cartChannel = null; }
  void unsubscribeReviews()      { _reviewsChannel?.unsubscribe();      _reviewsChannel = null; }

  void unsubscribeAll() {
    unsubscribeOrders();
    unsubscribeProducts();
    unsubscribeApplications();
    unsubscribeUsers();
    unsubscribeCart();
    unsubscribeReviews();
  }

  void dispose() {
    unsubscribeAll();
    _ordersController.close();
    _productsController.close();
    _applicationsController.close();
    _usersController.close();
    _cartController.close();
    _reviewsController.close();
  }
}
