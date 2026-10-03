import 'dart:convert';
import 'package:http/http.dart' as http;

class PsgcService {
  static const String baseUrl = 'https://psgc.gitlab.io/api';

  static final Map<String, dynamic> _cache = {
    'regions': null,
    'provinces': <String, List<Map<String, dynamic>>>{},
    'cities': <String, List<Map<String, dynamic>>>{},
    'barangays': <String, List<Map<String, dynamic>>>{},
  };

  static const List<Map<String, dynamic>> fallbackRegions = [
    {'code': '130000000', 'name': 'NCR', 'regionName': 'National Capital Region'},
    {'code': '010000000', 'name': 'Ilocos Region', 'regionName': 'Region I'},
    {'code': '020000000', 'name': 'Cagayan Valley', 'regionName': 'Region II'},
    {'code': '030000000', 'name': 'Central Luzon', 'regionName': 'Region III'},
    {'code': '040000000', 'name': 'CALABARZON', 'regionName': 'Region IV-A'},
    {'code': '170000000', 'name': 'MIMAROPA Region', 'regionName': 'MIMAROPA'},
    {'code': '050000000', 'name': 'Bicol Region', 'regionName': 'Region V'},
    {'code': '060000000', 'name': 'Western Visayas', 'regionName': 'Region VI'},
    {'code': '070000000', 'name': 'Central Visayas', 'regionName': 'Region VII'},
    {'code': '080000000', 'name': 'Eastern Visayas', 'regionName': 'Region VIII'},
    {'code': '090000000', 'name': 'Zamboanga Peninsula', 'regionName': 'Region IX'},
    {'code': '100000000', 'name': 'Northern Mindanao', 'regionName': 'Region X'},
    {'code': '110000000', 'name': 'Davao Region', 'regionName': 'Region XI'},
    {'code': '120000000', 'name': 'SOCCSKSARGEN', 'regionName': 'Region XII'},
    {'code': '140000000', 'name': 'CAR', 'regionName': 'Cordillera Administrative Region'},
    {'code': '160000000', 'name': 'Caraga', 'regionName': 'Region XIII'},
    {'code': '150000000', 'name': 'BARMM', 'regionName': 'Bangsamoro Autonomous Region in Muslim Mindanao'},
  ];

  static String formatRegionLabel(Map<String, dynamic> region) {
    String rName = (region['regionName'] ?? '').toString();
    String name = (region['name'] ?? '').toString();
    if (rName.isNotEmpty && name.isNotEmpty && !name.contains(rName)) {
      return '$rName - $name';
    }
    return rName.isNotEmpty ? rName : name;
  }

  static Future<List<Map<String, dynamic>>> getRegions() async {
    if (_cache['regions'] != null) {
      return List<Map<String, dynamic>>.from(_cache['regions']);
    }

    try {
      final response = await http.get(Uri.parse('$baseUrl/regions.json')).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final list = data.cast<Map<String, dynamic>>();
        list.sort((a, b) => formatRegionLabel(a).compareTo(formatRegionLabel(b)));
        _cache['regions'] = list;
        return list;
      }
    } catch (_) {}

    _cache['regions'] = fallbackRegions;
    return fallbackRegions;
  }

  static Future<List<Map<String, dynamic>>> getProvinces(String regionCode) async {
    if (regionCode.isEmpty) return [];
    final cacheMap = _cache['provinces'] as Map<String, List<Map<String, dynamic>>>;
    if (cacheMap.containsKey(regionCode)) return cacheMap[regionCode]!;

    if (regionCode == '130000000' || regionCode == '1300000000') {
      final ncr = [{'code': 'NCR', 'name': 'Metro Manila (NCR)'}];
      cacheMap[regionCode] = ncr;
      return ncr;
    }

    try {
      final response = await http.get(Uri.parse('$baseUrl/regions/$regionCode/provinces.json')).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final list = data.cast<Map<String, dynamic>>();
        if (list.isEmpty) {
          final def = [{'code': regionCode, 'name': 'Special Region / Direct Cities'}];
          cacheMap[regionCode] = def;
          return def;
        }
        list.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
        cacheMap[regionCode] = list;
        return list;
      }
    } catch (_) {}

    return [];
  }

  static Future<List<Map<String, dynamic>>> getCitiesMunicipalities(String regionCode, String provinceCode) async {
    if (regionCode.isEmpty) return [];
    final key = '${regionCode}_$provinceCode';
    final cacheMap = _cache['cities'] as Map<String, List<Map<String, dynamic>>>;
    if (cacheMap.containsKey(key)) return cacheMap[key]!;

    try {
      String url = '';
      if (provinceCode.isNotEmpty && provinceCode != 'NCR' && provinceCode != regionCode) {
        url = '$baseUrl/provinces/$provinceCode/cities-municipalities.json';
      } else {
        url = '$baseUrl/regions/$regionCode/cities-municipalities.json';
      }

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final list = data.cast<Map<String, dynamic>>();
        list.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
        cacheMap[key] = list;
        return list;
      }
    } catch (_) {}

    return [];
  }

  static Future<List<Map<String, dynamic>>> getBarangays(String cityCode) async {
    if (cityCode.isEmpty) return [];
    final cacheMap = _cache['barangays'] as Map<String, List<Map<String, dynamic>>>;
    if (cacheMap.containsKey(cityCode)) return cacheMap[cityCode]!;

    try {
      final response = await http.get(Uri.parse('$baseUrl/cities-municipalities/$cityCode/barangays.json')).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final list = data.cast<Map<String, dynamic>>();
        list.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
        cacheMap[cityCode] = list;
        return list;
      }
    } catch (_) {}

    return [];
  }
}
