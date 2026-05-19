import 'dart:async';
import 'package:flutter/foundation.dart';
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
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _notificationsChannel;

  final _ordersController       = StreamController<void>.broadcast();
  final _productsController     = StreamController<void>.broadcast();
  final _applicationsController = StreamController<void>.broadcast();
  final _usersController        = StreamController<void>.broadcast();
  final _cartController         = StreamController<void>.broadcast();
  final _reviewsController      = StreamController<void>.broadcast();
  final _messagesController     = StreamController<Map<String, dynamic>>.broadcast();
  final _notificationsController = StreamController<void>.broadcast();

  Stream<void> get ordersStream       => _ordersController.stream;
  Stream<void> get productsStream     => _productsController.stream;
  Stream<void> get applicationsStream => _applicationsController.stream;
  Stream<void> get usersStream        => _usersController.stream;
  Stream<void> get cartStream         => _cartController.stream;
  Stream<void> get reviewsStream      => _reviewsController.stream;
  /// Emits the full new message record whenever a message is inserted.
  Stream<Map<String, dynamic>> get messagesStream => _messagesController.stream;
  Stream<void> get notificationsStream => _notificationsController.stream;

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

  /// Rider-specific: listens to all order changes — catches new ready_for_pickup
  /// orders AND updates to orders assigned to this rider.
  /// Also subscribes to rider_earnings for real-time earnings updates.
  void subscribeRiderOrders({String? riderId}) {
    _ordersChannel?.unsubscribe();
    _ordersChannel = ApiService.client
        .channel('rider_orders_${riderId ?? 'all'}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            debugPrint('[Realtime] orders change: ${payload.eventType} status=${payload.newRecord["status"]}');
            _ordersController.add(null);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'rider_earnings',
          filter: riderId != null
              ? PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'rider_id', value: riderId)
              : null,
          callback: (_) => _ordersController.add(null),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: riderId != null
              ? PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: riderId)
              : null,
          callback: (_) => _ordersController.add(null),
        )
        .subscribe((RealtimeSubscribeStatus status, Object? error) {
          debugPrint('[Realtime] rider channel status: $status ${error ?? ""}');
        });
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
  void unsubscribeMessages()     { _messagesChannel?.unsubscribe();     _messagesChannel = null; }
  void unsubscribeNotifications(){ _notificationsChannel?.unsubscribe(); _notificationsChannel = null; }

  /// Subscribe to new messages for a specific conversation.
  /// Emits the full new record via [messagesStream].
  void subscribeMessages({required String convId}) {
    _messagesChannel?.unsubscribe();
    _messagesChannel = ApiService.client
        .channel('messages_conv_$convId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: convId,
          ),
          callback: (payload) {
            debugPrint('[Realtime] new message in conv $convId');
            final record = payload.newRecord;
            if (record.isNotEmpty) _messagesController.add(Map<String, dynamic>.from(record));
          },
        )
        .subscribe((status, err) {
          debugPrint('[Realtime] messages channel $convId: $status ${err ?? ""}');
        });
  }

  /// Subscribe to new messages in ANY conversation where user is a participant.
  /// Used by the conversation list to refresh unread counts.
  void subscribeConversations({required String userId}) {
    _messagesChannel?.unsubscribe();
    _messagesChannel = ApiService.client
        .channel('messages_user_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId,
          ),
          callback: (payload) {
            debugPrint('[Realtime] new message for user $userId');
            _messagesController.add(Map<String, dynamic>.from(payload.newRecord));
          },
        )
        .subscribe();
  }

  /// Subscribe to notifications for a specific user.
  void subscribeNotifications({required String userId}) {
    _notificationsChannel?.unsubscribe();
    _notificationsChannel = ApiService.client
        .channel('notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) {
            debugPrint('[Realtime] new notification for user $userId');
            _notificationsController.add(null);
          },
        )
        .subscribe();
  }

  void unsubscribeAll() {
    unsubscribeOrders();
    unsubscribeProducts();
    unsubscribeApplications();
    unsubscribeUsers();
    unsubscribeCart();
    unsubscribeReviews();
    unsubscribeMessages();
    unsubscribeNotifications();
  }

  void dispose() {
    unsubscribeAll();
    _ordersController.close();
    _productsController.close();
    _applicationsController.close();
    _usersController.close();
    _cartController.close();
    _reviewsController.close();
    _messagesController.close();
    _notificationsController.close();
  }
}
