import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Mirrors the web app's localStorage key `Grande_wishlist`.
/// Each item is a minimal product map: {id, name, price, image, seller_name, stock, total_stock}
class WishlistService {
  static const _key = 'Grande_wishlist';

  static Future<List<Map<String, dynamic>>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key) ?? '[]';
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> isWishlisted(String productId) async {
    final list = await getAll();
    return list.any((p) => p['id']?.toString() == productId);
  }

  /// Returns true if added, false if removed.
  static Future<bool> toggle(Map<String, dynamic> product) async {
    final list = await getAll();
    final idx = list.indexWhere((p) => p['id']?.toString() == product['id']?.toString());
    if (idx >= 0) {
      list.removeAt(idx);
      await _save(list);
      return false;
    } else {
      list.add(product);
      await _save(list);
      return true;
    }
  }

  static Future<void> remove(String productId) async {
    final list = await getAll();
    list.removeWhere((p) => p['id']?.toString() == productId);
    await _save(list);
  }

  static Future<void> _save(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list));
  }
}
