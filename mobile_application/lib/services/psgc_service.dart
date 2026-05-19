import 'dart:convert';
import 'package:http/http.dart' as http;

/// Mirrors psgc.js — fetches from https://psgc.gitlab.io/api
class PSGService {
  static const String _base = 'https://psgc.gitlab.io/api';

  static Future<List<Map<String, String>>> getRegions() async {
    return _fetch('regions/');
  }

  static Future<List<Map<String, String>>> getProvinces(String regionCode) async {
    return _fetch('regions/$regionCode/provinces/');
  }

  /// For regions with no provinces (e.g. NCR), fetch cities directly by region.
  static Future<List<Map<String, String>>> getCitiesByRegion(String regionCode) async {
    return _fetch('regions/$regionCode/cities-municipalities/');
  }

  static Future<List<Map<String, String>>> getCities(String provinceCode) async {
    final cities = await _fetch('provinces/$provinceCode/cities-municipalities/');
    if (cities.isEmpty) {
      // NCR-style region — caller should use getCitiesByRegion instead
    }
    return cities;
  }

  static Future<List<Map<String, String>>> getBarangays(String cityCode) async {
    return _fetch('cities-municipalities/$cityCode/barangays/');
  }

  /// Reverse geocode via Nominatim (same as psgc.js)
  static Future<Map<String, String>> reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&zoom=18&addressdetails=1',
      );
      final res = await http.get(uri, headers: {'User-Agent': 'GrandeMarketplace/1.0'});
      if (res.statusCode != 200) return {};
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final addr = (data['address'] as Map<String, dynamic>?) ?? {};
      return {
        'house_number': addr['house_number']?.toString() ?? '',
        'road':         addr['road']?.toString() ?? '',
        'postcode':     addr['postcode']?.toString() ?? '',
        'state':        addr['state']?.toString() ?? '',
        'province':     addr['province']?.toString() ?? addr['county']?.toString() ?? '',
        'city':         (addr['city'] ?? addr['town'] ?? addr['municipality'] ?? addr['city_district'] ?? addr['village'] ?? '').toString(),
        'suburb':       (addr['suburb'] ?? addr['neighbourhood'] ?? addr['quarter'] ?? addr['hamlet'] ?? '').toString(),
      };
    } catch (_) {
      return {};
    }
  }

  static Future<List<Map<String, String>>> _fetch(String endpoint) async {
    try {
      final res = await http.get(
        Uri.parse('$_base/$endpoint'),
        headers: {'User-Agent': 'GrandeMarketplace/1.0'},
      );
      if (res.statusCode != 200) return [];
      final list = jsonDecode(res.body) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map((item) => {
                'code': item['code']?.toString() ?? '',
                'name': item['name']?.toString() ?? '',
              })
          .where((item) => item['code']!.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
