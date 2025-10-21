import 'dart:convert';

/// Safely convert a dynamic value (often from decoded JSON or SQLite maps)
/// into a String. Handles null, String, num, Map and List gracefully.
String stringFromDynamic(dynamic v) {
  if (v == null) return '';
  if (v is String) return v;
  if (v is num) return v.toString();
  if (v is bool) return v ? 'true' : 'false';
  if (v is Map) {
    // Try common keys
    if (v.containsKey('name')) return v['name']?.toString() ?? '';
    if (v.containsKey('value')) return v['value']?.toString() ?? '';
    if (v.containsKey('url')) return v['url']?.toString() ?? '';
    // Fallback to JSON encoding so caller gets something useful
    try {
      return jsonEncode(v);
    } catch (_) {
      return v.toString();
    }
  }
  if (v is List) {
    try {
      return jsonEncode(v);
    } catch (_) {
      return v.map((e) => e?.toString() ?? '').join(',');
    }
  }

  try {
    return v.toString();
  } catch (_) {
    return '';
  }
}
