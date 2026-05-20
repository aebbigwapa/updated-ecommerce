import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String supabaseUrl = 'https://opusrotqhtkhmeefvydh.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9wdXNyb3RxaHRraG1lZWZ2eWRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc1NTU3MzMsImV4cCI6MjA5MzEzMTczM30.-Lo362tNRftWbvXK2kds7r5CpDeXb5vYN6K3rBhQlvw';

  // Flask backend base URL
  // Use your machine IP for physical devices on the same Wi-Fi.
  // Override using --dart-define=FLASK_BASE_URL=http://<host-ip>:5000
  static final String flaskBaseUrl = () {
    const envUrl = String.fromEnvironment('FLASK_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    return 'http://192.168.123.36:5000';
  }();

  static final ValueNotifier<int> cartCount = ValueNotifier<int>(0);

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> init() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  // ── Session helpers ──────────────────────────────────────────

  static Future<void> _saveSession(Map<String, dynamic> user, {String token = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', user['id']?.toString() ?? '');
    await prefs.setString('user_email', user['email']?.toString() ?? '');
    await prefs.setString('user_first_name', user['first_name']?.toString() ?? '');
    await prefs.setString('user_last_name', user['last_name']?.toString() ?? '');
    await prefs.setString('user_role', user['role']?.toString() ?? 'user');
    if (token.isNotEmpty) await prefs.setString('auth_token', token);
  }

  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_first_name');
    await prefs.remove('user_last_name');
    await prefs.remove('user_role');
    await prefs.remove('auth_token');
  }

  static Future<String?> _getSessionUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  // ── Authentication ───────────────────────────────────────────

  /// Login via Flask API (uses service role key server-side, bypasses RLS)
  static Future<Map<String, dynamic>> loginFlask(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$flaskBaseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json', 'X-Client-Type': 'mobile'},
        body: jsonEncode({'email': email.trim().toLowerCase(), 'password': password}),
      ).timeout(const Duration(seconds: 30));
      final body = _decodeJson(res.body);
      if (res.statusCode == 200) {
        final data  = body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : <String, dynamic>{};
        final user  = data['user']  is Map ? Map<String, dynamic>.from(data['user']  as Map) : <String, dynamic>{};
        final token = data['token']?.toString() ?? '';
        if (user.isNotEmpty) {
          await _saveSession(user, token: token);
          return {'success': true, 'user': user};
        }
      }
      return {'success': false, 'message': body['error']?.toString() ?? body['message']?.toString() ?? 'Invalid email or password'};
    } on TimeoutException {
      return {'success': false, 'message': 'Connection timed out. Make sure the server is running and reachable.'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> loginVerifyOtp(String email, String otp) async {
    try {
      final res = await http.post(
        Uri.parse('$flaskBaseUrl/api/auth/login-verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim().toLowerCase(), 'otp': otp.trim()}),
      );
      final body = _decodeJson(res.body);
      if (res.statusCode == 200) {
        final data  = body['data']  is Map ? Map<String, dynamic>.from(body['data']  as Map) : <String, dynamic>{};
        final user  = data['user']  is Map ? Map<String, dynamic>.from(data['user']  as Map) : <String, dynamic>{};
        final token = data['token']?.toString() ?? '';
        if (user.isNotEmpty) {
          await _saveSession(user, token: token);
          return {'success': true, 'user': user};
        }
      }
      return {'success': false, 'message': body['error']?.toString() ?? body['message']?.toString() ?? 'Invalid OTP'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Legacy direct Supabase login — kept for fallback only
  static Future<Map<String, dynamic>?> login(String email, String password) async {
    final result = await loginFlask(email, password);
    if (result['success'] == true) return result['user'] as Map<String, dynamic>?;
    return null;
  }

  static Future<bool> register(Map<String, dynamic> userData) async {
    try {
      final userId = _generateUuid();
      await client.from('users').insert({
        'id': userId,
        'first_name': userData['first_name'],
        'middle_name': userData['middle_name'],
        'last_name': userData['last_name'],
        'email': userData['email'].toString().trim().toLowerCase(),
        'password': userData['password'],
        'phone': userData['phone'],
        'gender': userData['gender'],
        'role': userData['role'] ?? 'buyer',
      });

      // Create application record
      final appData = <String, dynamic>{
        'user_id': userId,
        'role': userData['role'] ?? 'buyer',
        'status': 'pending',
      };
      if (userData['role'] == 'seller') {
        appData['store_name'] = userData['store_name'];
        appData['store_category'] = userData['store_category'];
        appData['store_description'] = userData['store_description'];
      } else if (userData['role'] == 'rider') {
        appData['vehicle_type'] = userData['vehicle_type'];
        appData['license_number'] = userData['license_number'];
      }
      await client.from('applications').insert(appData);

      // Save address if provided
      if (userData['region'] != null && userData['region'].toString().isNotEmpty) {
        await client.from('addresses').insert({
          'user_id': userId,
          'region': userData['region'],
          'city': userData['city'],
          'barangay': userData['barangay'],
          'street': userData['street'],
          'zip_code': userData['zip_code'],
          'is_default': true,
        });
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  static String _generateUuid() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = now ^ (now >> 16);
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replaceAllMapped(
      RegExp(r'[xy]'),
      (m) {
        final r = (rand + m.start * 16) % 16;
        final v = m.group(0) == 'x' ? r : (r & 0x3 | 0x8);
        return v.toRadixString(16);
      },
    );
  }

  // ── Flask API: OTP + Registration ──────────────────────────

  static Future<Map<String, dynamic>> sendOtpFlask(String email) async {
    try {
      final res = await http.post(
        Uri.parse('$flaskBaseUrl/api/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: '{"email":"${email.trim().toLowerCase()}"}',
      );
      final body = _decodeJson(res.body);
      return {'success': res.statusCode == 200, 'message': body['message'] ?? body['error'] ?? ''};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> verifyOtpFlask(String email, String otp, {String purpose = ''}) async {
    try {
      final res = await http.post(
        Uri.parse('$flaskBaseUrl/api/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'otp': otp.trim(),
          'purpose': purpose,
        }),
      );
      final body = _decodeJson(res.body);
      return {'success': res.statusCode == 200, 'message': body['message'] ?? body['error'] ?? ''};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> resetPasswordFlask(String email, String otp, String newPassword) async {
    try {
      final uri = Uri.parse('$flaskBaseUrl/api/auth/reset-password');
      print('Sending reset-password request to: $uri');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'otp': otp.trim(),
          'new_password': newPassword,
        }),
      ).timeout(const Duration(seconds: 15));
      final body = _decodeJson(res.body);
      print('Reset-password response: status=${res.statusCode}, body=$body');
      return {'success': res.statusCode == 200, 'message': body['message'] ?? body['error'] ?? ''};
    } on TimeoutException {
      final msg = 'Connection timeout. Check if backend server is running at $flaskBaseUrl';
      print('Reset-password error: $msg');
      return {'success': false, 'message': msg};
    } catch (e) {
      final msg = 'Network error: $e. Backend: $flaskBaseUrl';
      print('Reset-password exception: $msg');
      return {'success': false, 'message': msg};
    }
  }

  static Future<Map<String, dynamic>> registerFlask({
    required Map<String, String> fields,
    Map<String, File> files = const {},
  }) async {
    try {
      final uri = Uri.parse('$flaskBaseUrl/api/auth/register');
      final req = http.MultipartRequest('POST', uri);
      fields.forEach((k, v) => req.fields[k] = v);
      for (final entry in files.entries) {
        req.files.add(await http.MultipartFile.fromPath(entry.key, entry.value.path));
      }
      final streamed = await req.send();
      final body = _decodeJson(await streamed.stream.bytesToString());
      return {
        'success': streamed.statusCode == 201,
        'message': body['message'] ?? body['error'] ?? '',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getSellerStats(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$flaskBaseUrl/api/seller/stats'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      return _decodeJson(res.body)['data'] ?? {};
    } catch (_) { return {}; }
  }

  static Future<Map<String, dynamic>> getRiderStats(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$flaskBaseUrl/api/rider/stats'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      return _decodeJson(res.body)['data'] ?? {};
    } catch (_) { return {}; }
  }

  static Future<Map<String, dynamic>> getRiderDashboard(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$flaskBaseUrl/api/rider/dashboard'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      final body = _decodeJson(res.body);
      final data = body['data'];
      return data is Map ? Map<String, dynamic>.from(data as Map) : body;
    } catch (_) { return {}; }
  }

  static Future<List<Map<String, dynamic>>> getRiderDeliveries(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$flaskBaseUrl/api/rider/deliveries'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      final body = _decodeJson(res.body);
      final data = body['data'];
      if (data is Map && data['deliveries'] is List) {
        return List<Map<String, dynamic>>.from(
            (data['deliveries'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
      }
      return [];
    } catch (_) { return []; }
  }

  static Future<Map<String, dynamic>> riderAcceptDelivery(String orderId, String token) async {
    try {
      final res = await http.post(
        Uri.parse('$flaskBaseUrl/api/rider/deliveries/$orderId/accept'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      final body = _decodeJson(res.body);
      return {'success': res.statusCode == 200, 'message': body['message']?.toString() ?? ''};
    } catch (e) { return {'success': false, 'message': e.toString()}; }
  }

  static Future<Map<String, dynamic>> riderMarkDelivered(String orderId, String token) async {
    try {
      final res = await http.post(
        Uri.parse('$flaskBaseUrl/api/rider/deliveries/$orderId/delivered'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      final body = _decodeJson(res.body);
      return {'success': res.statusCode == 200, 'message': body['message']?.toString() ?? ''};
    } catch (e) { return {'success': false, 'message': e.toString()}; }
  }

  static Future<Map<String, dynamic>> riderDeclineDelivery(String orderId, String token, String reason, {String note = ''}) async {
    try {
      final res = await http.post(
        Uri.parse('$flaskBaseUrl/api/rider/deliveries/$orderId/decline'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'reason': reason, 'note': note}),
      ).timeout(const Duration(seconds: 10));
      final body = _decodeJson(res.body);
      return {'success': res.statusCode == 200, 'message': body['message']?.toString() ?? ''};
    } catch (e) { return {'success': false, 'message': e.toString()}; }
  }

  static Future<Map<String, dynamic>> riderReportIssue(String orderId, String token, String reason, {String note = ''}) async {
    try {
      final res = await http.post(
        Uri.parse('$flaskBaseUrl/api/rider/deliveries/$orderId/report'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'reason': reason, 'note': note}),
      ).timeout(const Duration(seconds: 10));
      final body = _decodeJson(res.body);
      return {'success': res.statusCode == 200, 'message': body['message']?.toString() ?? ''};
    } catch (e) { return {'success': false, 'message': e.toString()}; }
  }

  static Future<Map<String, dynamic>> riderUploadProof(String orderId, String token, File imageFile) async {
    try {
      final uri = Uri.parse('$flaskBaseUrl/api/rider/deliveries/$orderId/proof');
      final req = http.MultipartRequest('POST', uri);
      req.headers['Authorization'] = 'Bearer $token';
      req.files.add(await http.MultipartFile.fromPath('proof_image', imageFile.path));
      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final body = _decodeJson(await streamed.stream.bytesToString());
      return {'success': streamed.statusCode == 200, 'message': body['message']?.toString() ?? '', 'proof_url': (body['data'] is Map) ? (body['data'] as Map)['proof_url'] : null};
    } catch (e) { return {'success': false, 'message': e.toString()}; }
  }

  static Future<Map<String, dynamic>> riderGetDeclineReasons(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$flaskBaseUrl/api/rider/decline-reasons'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      final body = _decodeJson(res.body);
      final data = body['data'];
      return data is Map ? Map<String, dynamic>.from(data as Map) : {};
    } catch (_) { return {}; }
  }

  static Future<Map<String, dynamic>> riderGetAvailability(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$flaskBaseUrl/api/rider/availability'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      final body = _decodeJson(res.body);
      final data = body['data'];
      return data is Map ? Map<String, dynamic>.from(data as Map) : {};
    } catch (_) { return {}; }
  }

  static Future<Map<String, dynamic>> riderSetAvailability(String token, bool isAvailable) async {
    try {
      final res = await http.post(
        Uri.parse('$flaskBaseUrl/api/rider/availability'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'is_available': isAvailable}),
      ).timeout(const Duration(seconds: 10));
      final body = _decodeJson(res.body);
      return {'success': res.statusCode == 200, 'is_available': (body['data'] is Map) ? (body['data'] as Map)['is_available'] : isAvailable};
    } catch (e) { return {'success': false}; }
  }

  static Future<Map<String, dynamic>> riderGetPerformance(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$flaskBaseUrl/api/rider/performance'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      final body = _decodeJson(res.body);
      final data = body['data'];
      return data is Map ? Map<String, dynamic>.from(data as Map) : {};
    } catch (_) { return {}; }
  }

  static Future<Map<String, dynamic>> riderGetNotifications(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$flaskBaseUrl/api/rider/notifications'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      final body = _decodeJson(res.body);
      final data = body['data'];
      return data is Map ? Map<String, dynamic>.from(data as Map) : {};
    } catch (_) { return {}; }
  }

  static Future<void> riderMarkNotifsRead(String token) async {
    try {
      await http.post(
        Uri.parse('$flaskBaseUrl/api/rider/notifications/read-all'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> getBuyerNotifications(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$flaskBaseUrl/api/buyer/notifications'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      final body = _decodeJson(res.body);
      final data = body['data'];
      return data is Map ? Map<String, dynamic>.from(data as Map) : {};
    } catch (_) { return {}; }
  }

  static Future<void> markBuyerNotifsRead(String token) async {
    try {
      await http.post(
        Uri.parse('$flaskBaseUrl/api/buyer/notifications/read-all'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> riderGetProfile(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$flaskBaseUrl/api/rider/profile'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      final body = _decodeJson(res.body);
      final data = body['data'];
      return data is Map ? Map<String, dynamic>.from(data as Map) : {};
    } catch (_) { return {}; }
  }

  static Future<Map<String, dynamic>> riderSaveProfile(String token, Map<String, dynamic> payload) async {
    try {
      final res = await http.post(
        Uri.parse('$flaskBaseUrl/api/rider/profile'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));
      final body = _decodeJson(res.body);
      return {'success': res.statusCode == 200, 'message': body['message']?.toString() ?? ''};
    } catch (e) { return {'success': false, 'message': e.toString()}; }
  }

  static Future<Map<String, dynamic>> getAdminStats(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$flaskBaseUrl/api/admin/stats'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      return _decodeJson(res.body)['data'] ?? {};
    } catch (_) { return {}; }
  }

  static Map<String, dynamic> _decodeJson(String raw) {
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  // ── Messages API ───────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getConversations(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$flaskBaseUrl/api/messages/conversations'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      final body = _decodeJson(res.body);
      if (res.statusCode == 200) {
        final data = body['data'];
        if (data is List) {
          return List<Map<String, dynamic>>.from(
              data.map((e) => Map<String, dynamic>.from(e as Map)));
        }
      }
      return [];
    } catch (_) { return []; }
  }

  static Future<Map<String, dynamic>> startConversation(
      String token, String otherId, {String? orderId}) async {
    try {
      final res = await http.post(
        Uri.parse('$flaskBaseUrl/api/messages/conversations'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'other_id': otherId, if (orderId != null) 'order_id': orderId}),
      ).timeout(const Duration(seconds: 10));
      final body = _decodeJson(res.body);
      return body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : {};
    } catch (_) { return {}; }
  }

  static Future<List<Map<String, dynamic>>> getMessages(
      String token, String convId, {String? afterId}) async {
    try {
      final uri = afterId != null
          ? Uri.parse('$flaskBaseUrl/api/messages/conversations/$convId/messages?after=$afterId')
          : Uri.parse('$flaskBaseUrl/api/messages/conversations/$convId/messages');
      final res = await http.get(uri,
          headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 10));
      final body = _decodeJson(res.body);
      if (res.statusCode == 200) {
        final data = body['data'];
        if (data is List) {
          return List<Map<String, dynamic>>.from(
              data.map((e) => Map<String, dynamic>.from(e as Map)));
        }
      }
      return [];
    } catch (_) { return []; }
  }

  static Future<Map<String, dynamic>?> sendMessage(
      String token, String convId, String content) async {
    try {
      final res = await http.post(
        Uri.parse('$flaskBaseUrl/api/messages/conversations/$convId/messages'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'content': content}),
      ).timeout(const Duration(seconds: 10));
      final body = _decodeJson(res.body);
      if (res.statusCode == 201) {
        final data = body['data'];
        return data is Map ? Map<String, dynamic>.from(data as Map) : null;
      }
      return null;
    } catch (_) { return null; }
  }

  static Future<int> getUnreadMessageCount(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$flaskBaseUrl/api/messages/unread-count'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 5));
      final body = _decodeJson(res.body);
      if (res.statusCode == 200) {
        final data = body['data'];
        return (data is Map ? data['count'] : null) as int? ?? 0;
      }
      return 0;
    } catch (_) { return 0; }
  }

  // ── Legacy Supabase OTP (kept for compatibility) ─────────────

  static Future<bool> sendOtp(String email) async {
    final result = await sendOtpFlask(email);
    return result['success'] == true;
  }

  static Future<bool> verifyOtp(String email, String otp) async {
    final result = await verifyOtpFlask(email, otp);
    return result['success'] == true;
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final userId = await _getSessionUserId();
    if (userId == null) return null;

    try {
      final response = await client
          .from('users')
          .select('id, email, first_name, last_name, role')
          .eq('id', userId)
          .single();

      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<void> logout() async {
    await _clearSession();
  }

  // ── Products ─────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getProducts({
    int? limit,
    String? category,
    String? sortBy,
    String? sortOrder = 'asc',
  }) async {
    try {
      final params = <String, String>{};
      if (category != null) params['category'] = category;
      final uri = Uri.parse('$flaskBaseUrl/api/products').replace(queryParameters: params.isEmpty ? null : params);
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        print('[getProducts] HTTP ${res.statusCode}: ${res.body}');
        return [];
      }
      final body = _decodeJson(res.body);
      final data = body['data'];
      List<dynamic> products = [];
      if (data is Map && data['products'] is List) {
        products = data['products'] as List;
      } else if (data is List) {
        products = data;
      } else {
        print('[getProducts] Unexpected data shape: $data');
      }
      var result = List<Map<String, dynamic>>.from(
        products.map((e) => Map<String, dynamic>.from(e as Map)),
      );
      if (sortBy == 'created_at') {
        result.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
      }
      if (limit != null && result.length > limit) {
        result = result.sublist(0, limit);
      }
      return result;
    } catch (e) {
      print('[getProducts] Exception: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getProduct(String productId) async {
    try {
      final res = await http.get(
        Uri.parse('$flaskBaseUrl/api/products/$productId'),
      ).timeout(const Duration(seconds: 10));
      final body = _decodeJson(res.body);
      if (res.statusCode == 200) {
        final data = body['data'];
        if (data is Map && data['product'] is Map) {
          return Map<String, dynamic>.from(data['product'] as Map);
        }
      }
      return null;
    } catch (e) { return null; }
  }

  // ── Seller Products ────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getSellerProducts(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$flaskBaseUrl/api/seller/products'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final body = _decodeJson(res.body);
      if (res.statusCode == 200) {
        final data = body['data'];
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map) {
          final list = (data['products'] as List?) ?? [];
          return List<Map<String, dynamic>>.from(list);
        }
      }
      return [];
    } catch (e) { return []; }
  }

  static Future<Map<String, dynamic>> createProductMultipart(
    String sellerId,
    Map<String, String> fields,
    List<File> imageFiles,
  ) async {
    try {
      final uri = Uri.parse('$flaskBaseUrl/api/seller/products');
      final req = http.MultipartRequest('POST', uri);

      // Add all form fields
      fields.forEach((k, v) => req.fields[k] = v);

      // Add all images
      for (int i = 0; i < imageFiles.length; i++) {
        final file = imageFiles[i];
        req.files.add(await http.MultipartFile.fromPath('image_$i', file.path));
      }

      final streamed = await req.send();
      final body = _decodeJson(await streamed.stream.bytesToString());
      return {
        'success': streamed.statusCode == 201,
        'error': body['error']?.toString(),
        'message': body['message']?.toString(),
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateProductMultipart(
    String productId,
    Map<String, String> fields,
    List<File> imageFiles,
  ) async {
    try {
      final uri = Uri.parse('$flaskBaseUrl/api/seller/products/$productId');
      final req = http.MultipartRequest('PUT', uri);
      fields.forEach((k, v) => req.fields[k] = v);
      for (int i = 0; i < imageFiles.length; i++) {
        req.files.add(await http.MultipartFile.fromPath('image_$i', imageFiles[i].path));
      }
      final streamed = await req.send();
      final body = _decodeJson(await streamed.stream.bytesToString());
      return {
        'success': streamed.statusCode == 200,
        'error': body['error']?.toString(),
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteProduct(String productId, String token) async {
    try {
      final res = await http.delete(
        Uri.parse('$flaskBaseUrl/api/seller/products/$productId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final body = _decodeJson(res.body);
      return {'success': res.statusCode == 200, 'message': body['message']?.toString()};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getSellerOrders(String token) async {
    try {
      final res = await http.get(Uri.parse('$flaskBaseUrl/api/seller/orders'), headers: {'Authorization': 'Bearer $token'});
      final body = _decodeJson(res.body);
      if (res.statusCode == 200) {
        final data = body['data'] is List ? body['data'] : (body['orders'] ?? []);
        return {'success': true, 'orders': data};
      }
      return {'success': false, 'error': body['error']?.toString()};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getSellerEarnings(String token) async {
    try {
      final res = await http.get(Uri.parse('$flaskBaseUrl/api/seller/earnings'), headers: {'Authorization': 'Bearer $token'});
      final body = _decodeJson(res.body);
      if (res.statusCode == 200) {
        final data = body['data'] ?? body;
        return {'success': true, 'stats': data};
      }
      return {'success': false, 'error': body['error']?.toString()};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateOrderStatus(String orderId, String status, String token) async {
    try {
      final res = await http.post(
        Uri.parse('$flaskBaseUrl/api/seller/orders/$orderId/status'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'status': status}),
      );
      final body = _decodeJson(res.body);
      return {'success': res.statusCode == 200, 'message': body['message']?.toString(), 'order': body['order']};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Generic GET helper with token
  static Future<Map<String, dynamic>> get(String path, {required String token}) async {
    try {
      final res = await http.get(Uri.parse('$flaskBaseUrl$path'), headers: {'Authorization': 'Bearer $token'});
      final body = _decodeJson(res.body);
      if (res.statusCode == 200) {
        return body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : body;
      }
      return {'error': body['error']?.toString() ?? 'Request failed', 'success': false};
    } catch (e) {
      return {'error': e.toString(), 'success': false};
    }
  }

  static Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body, {required String token}) async {
    try {
      final res = await http.post(
        Uri.parse('$flaskBaseUrl$path'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(body),
      );
      return _decodeJson(res.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> delete(String path, {required String token}) async {
    try {
      final res = await http.delete(Uri.parse('$flaskBaseUrl$path'), headers: {'Authorization': 'Bearer $token'});
      final body = _decodeJson(res.body);
      return {'success': res.statusCode == 200, 'message': body['message']?.toString()};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>?> getApplication(String userId) async {
    try {
      final response = await client
          .from('applications')
          .select()
          .eq('user_id', userId)
          .eq('role', 'seller')
          .single();
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> addToCart(String productId, int quantity, {String? variantId}) async {
    try {
      final token = await getAuthToken();
      if (token == null) return {'success': false, 'message': 'Not logged in'};
      final body = <String, dynamic>{'product_id': productId, 'quantity': quantity};
      if (variantId != null) body['variant_id'] = variantId;
      final res = await http.post(
        Uri.parse('$flaskBaseUrl/api/cart'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
      final decoded = _decodeJson(res.body);
      return {
        'success': res.statusCode == 200 || res.statusCode == 201,
        'message': decoded['message'] ?? decoded['error'] ?? '',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<bool> updateCartItem(String itemId, int quantity) async {
    try {
      final token = await getAuthToken();
      if (token == null) return false;
      final res = await http.patch(
        Uri.parse('$flaskBaseUrl/api/cart/$itemId'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'quantity': quantity}),
      ).timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> removeFromCart(String itemId) async {
    try {
      final token = await getAuthToken();
      if (token == null) return false;
      final res = await http.delete(
        Uri.parse('$flaskBaseUrl/api/cart/$itemId'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ── Cart ─────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getCart() async {
    try {
      final token = await getAuthToken();
      if (token == null) return [];
      final res = await http.get(
        Uri.parse('$flaskBaseUrl/api/cart'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      final body = _decodeJson(res.body);
      if (res.statusCode == 200) {
        final data = body['data'];
        if (data is Map && data['items'] is List) {
          return List<Map<String, dynamic>>.from(
            (data['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
          );
        }
      }
      return [];
    } catch (e) { return []; }
  }

  static Future<int> getCartCount() async {
    final items = await getCart();
    final count = items.fold<int>(0, (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 1));
    cartCount.value = count;
    return count;
  }

  static Future<int> refreshCartCount() async {
    return getCartCount();
  }

  // ── Orders ───────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getOrders() async {
    try {
      final token = await getAuthToken();
      if (token == null) return [];
      final res = await http.get(
        Uri.parse('$flaskBaseUrl/api/orders'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      final body = _decodeJson(res.body);
      if (res.statusCode == 200) {
        final data = body['data'];
        if (data is Map && data['orders'] is List) {
          return List<Map<String, dynamic>>.from(
            (data['orders'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
          );
        }
      }
      return [];
    } catch (e) { return []; }
  }

  static Future<Map<String, dynamic>?> getOrder(String orderId) async {
    try {
      final token = await getAuthToken();
      if (token == null) return null;
      final res = await http.get(
        Uri.parse('$flaskBaseUrl/api/orders/$orderId'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      final body = _decodeJson(res.body);
      if (res.statusCode == 200) {
        final data = body['data'];
        if (data is Map && data['order'] is Map) {
          return Map<String, dynamic>.from(data['order'] as Map);
        }
      }
      return null;
    } catch (e) { return null; }
  }

  static Future<List<Map<String, dynamic>>> getAddresses() async {
    try {
      final token = await getAuthToken();
      if (token == null) return [];
      final res = await http.get(
        Uri.parse('$flaskBaseUrl/api/addresses'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      final body = _decodeJson(res.body);
      if (res.statusCode == 200) {
        final data = body['data'];
        if (data is Map && data['addresses'] is List) {
          return List<Map<String, dynamic>>.from(
            (data['addresses'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
          );
        }
      }
      return [];
    } catch (e) { return []; }
  }

  static Future<Map<String, dynamic>> cancelOrder(String orderId) async {
    try {
      final token = await getAuthToken();
      if (token == null) return {'success': false, 'error': 'Not logged in'};
      final res = await http.post(
        Uri.parse('$flaskBaseUrl/api/orders/$orderId/cancel'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      final body = _decodeJson(res.body);
      return {'success': res.statusCode == 200, 'error': body['error'], 'message': body['message']};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> createOrder({
    required String address,
    String paymentMethod = 'cod',
    String? addressId,
    String? notes,
  }) async {
    try {
      final token = await getAuthToken();
      if (token == null) return {'success': false, 'error': 'Not logged in'};
      final res = await http.post(
        Uri.parse('$flaskBaseUrl/api/orders'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          'address': address,
          'payment_method': paymentMethod,
          'address_id': addressId,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        }),
      ).timeout(const Duration(seconds: 15));
      final body = _decodeJson(res.body);
      return {
        'success': res.statusCode == 201,
        'error': body['error'],
        'message': body['message'],
        'order': body['data'] is Map ? body['data']['order'] : null,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ── Profile ──────────────────────────────────────────────────

  static Future<bool> updateProfile(Map<String, dynamic> profileData) async {
    try {
      final userId = await _getSessionUserId();
      if (userId == null) return false;

      await client.from('users').update(profileData).eq('id', userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      final userId = await _getSessionUserId();
      if (userId == null) return false;

      // Verify current password first
      final user = await client
          .from('users')
          .select('password')
          .eq('id', userId)
          .single();

      if (user['password'] != currentPassword) return false;

      await client.from('users').update({'password': newPassword}).eq('id', userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Seller API ───────────────────────────────────────────

  static Future<Map<String, dynamic>> _authGet(String path) async {
    final token = await getAuthToken() ?? '';
    final res = await http.get(
      Uri.parse('$flaskBaseUrl$path'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));
    return _decodeJson(res.body);
  }

  static Future<Map<String, dynamic>> _authPost(String path, Map<String, dynamic> body) async {
    final token = await getAuthToken() ?? '';
    final res = await http.post(
      Uri.parse('$flaskBaseUrl$path'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 10));
    return _decodeJson(res.body);
  }

  static Future<Map<String, dynamic>> sellerGetDashboard() async {
    final body = await _authGet('/api/seller/dashboard');
    return body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : {};
  }

  static Future<List<Map<String, dynamic>>> sellerGetProducts() async {
    final body = await _authGet('/api/seller/products');
    final data = body['data'];
    if (data is Map && data['products'] is List) {
      return List<Map<String, dynamic>>.from(
          (data['products'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
    }
    return [];
  }

  static Future<String?> sellerGetCategory() async {
    final body = await _authGet('/api/seller/category');
    final data = body['data'];
    if (data is Map) return data['category']?.toString();
    return null;
  }

  static Future<Map<String, dynamic>> sellerCreateProduct({
    required Map<String, String> fields,
    Map<String, File> images = const {},
    List<File> imagesList = const [],
  }) async {
    final token = await getAuthToken() ?? '';
    final req = http.MultipartRequest(
        'POST', Uri.parse('$flaskBaseUrl/api/seller/products'));
    req.headers['Authorization'] = 'Bearer $token';
    fields.forEach((k, v) => req.fields[k] = v);
    // Named images (e.g. variant_image_0)
    for (final e in images.entries) {
      req.files.add(await http.MultipartFile.fromPath(e.key, e.value.path));
    }
    // General images sent as images[]
    for (final img in imagesList) {
      req.files.add(await http.MultipartFile.fromPath('images[]', img.path));
    }
    final streamed = await req.send().timeout(const Duration(seconds: 30));
    final body = _decodeJson(await streamed.stream.bytesToString());
    return {
      'success': streamed.statusCode == 201,
      'message': body['message']?.toString() ?? body['error']?.toString() ?? '',
      'product_id': (body['data'] is Map) ? (body['data'] as Map)['product_id']?.toString() : null,
    };
  }

  static Future<Map<String, dynamic>> sellerDeleteProduct(String productId) async {
    final token = await getAuthToken() ?? '';
    final res = await http.delete(
      Uri.parse('$flaskBaseUrl/api/seller/products/$productId'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));
    final body = _decodeJson(res.body);
    return {'success': res.statusCode == 200, 'message': body['message']?.toString() ?? ''};
  }

  static Future<Map<String, dynamic>> sellerUpdateProduct(
    String productId, {
    required Map<String, String> fields,
    Map<String, File> images = const {},
    List<File> imagesList = const [],
  }) async {
    final token = await getAuthToken() ?? '';
    final req = http.MultipartRequest(
        'PUT', Uri.parse('$flaskBaseUrl/api/seller/products/$productId'));
    req.headers['Authorization'] = 'Bearer $token';
    fields.forEach((k, v) => req.fields[k] = v);
    for (final e in images.entries) {
      req.files.add(await http.MultipartFile.fromPath(e.key, e.value.path));
    }
    for (final img in imagesList) {
      req.files.add(await http.MultipartFile.fromPath('images[]', img.path));
    }
    final streamed = await req.send().timeout(const Duration(seconds: 30));
    final body = _decodeJson(await streamed.stream.bytesToString());
    return {
      'success': streamed.statusCode == 200,
      'message': body['message']?.toString() ?? body['error']?.toString() ?? '',
    };
  }

  static Future<List<Map<String, dynamic>>> sellerGetOrders() async {
    final body = await _authGet('/api/seller/orders');
    final data = body['data'];
    if (data is Map && data['orders'] is List) {
      return List<Map<String, dynamic>>.from(
          (data['orders'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
    }
    return [];
  }

  static Future<Map<String, dynamic>> sellerUpdateOrderStatus(
      String orderId, String status) async {
    final body = await _authPost('/api/seller/orders/$orderId/status', {'status': status});
    return {'success': body['success'] == true, 'message': body['message']?.toString() ?? ''};
  }

  // ── Reviews ──────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getReviews({String? productId}) async {
    try {
      var query = client.from('reviews').select('*, user:users(first_name, last_name)');

      if (productId != null) {
        query = query.eq('product_id', productId);
      }

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  static Future<bool> createReview(Map<String, dynamic> reviewData) async {
    try {
      final userId = await _getSessionUserId();
      if (userId == null) return false;

      await client.from('reviews').insert({
        'user_id': userId,
        ...reviewData,
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  // ── GCash Payment Proof ──────────────────────────────────────

  static Future<Map<String, dynamic>> uploadPaymentProof(String orderId, File imageFile) async {
    try {
      final token = await getAuthToken();
      if (token == null) return {'success': false, 'error': 'Not logged in'};

      final uri = Uri.parse('$flaskBaseUrl/buyer/orders/$orderId/upload-proof');
      final req = http.MultipartRequest('POST', uri);
      req.headers['Authorization'] = 'Bearer $token';
      req.files.add(await http.MultipartFile.fromPath('receipt', imageFile.path));

      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final body = _decodeJson(await streamed.stream.bytesToString());

      return {
        'success': streamed.statusCode == 200,
        'error': body['error']?.toString(),
        'message': body['message']?.toString(),
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingPaymentOrders() async {
    try {
      final token = await getAuthToken();
      if (token == null) return [];

      final res = await http.get(
        Uri.parse('$flaskBaseUrl/seller/verify-payments'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      // This endpoint returns HTML, so we need to call the API endpoint instead
      // Let's use the seller orders endpoint and filter for pending_payment
      final ordersRes = await http.get(
        Uri.parse('$flaskBaseUrl/api/seller/orders'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      final body = _decodeJson(ordersRes.body);
      if (ordersRes.statusCode == 200) {
        final data = body['data'];
        List<dynamic> orders = [];
        if (data is Map && data['orders'] is List) {
          orders = data['orders'] as List;
        } else if (data is List) {
          orders = data;
        }

        // Filter for pending_payment status with payment_proof_url
        final pendingPayments = orders
            .where((o) => 
                o['status'] == 'pending_payment' && 
                o['payment_proof_url'] != null &&
                o['payment_proof_url'].toString().isNotEmpty)
            .toList();

        return List<Map<String, dynamic>>.from(
          pendingPayments.map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }
      return [];
    } catch (e) {
      print('[getPendingPaymentOrders] Error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> verifyPayment(
      String orderId, bool approved, String? reason) async {
    try {
      final token = await getAuthToken();
      if (token == null) return {'success': false, 'error': 'Not logged in'};

      final res = await http.post(
        Uri.parse('$flaskBaseUrl/seller/orders/$orderId/verify-payment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'approved': approved,
          if (reason != null) 'reason': reason,
        }),
      ).timeout(const Duration(seconds: 15));

      final body = _decodeJson(res.body);
      return {
        'success': res.statusCode == 200,
        'error': body['error']?.toString(),
        'message': body['message']?.toString(),
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
