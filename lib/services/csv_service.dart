import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/cloud_spot.dart';
import '../utils/cloud_utils.dart';
import '../utils/date_utils.dart';

class CsvDateInfo {
  final List<String> availableDates;
  final DateTime minDate;
  final DateTime maxDate;
  CsvDateInfo(this.availableDates, this.minDate, this.maxDate);
}

class CsvService {
  static List<List<dynamic>>? _csvRowsCache;
  static List<dynamic>? _csvHeaderCache;

  static Future<void> ensureCsvLoaded() async {
    if (_csvRowsCache != null && _csvHeaderCache != null) return;
    final response = await http.get(Uri.parse(
      'https://raw.githubusercontent.com/tommyiaq/privacy-policy/main/assets/pluvio_completi.csv',
    ));
    if (response.statusCode != 200) {
      throw Exception('Failed to load CSV');
    }
    final raw = response.body;
    final rows = const CsvToListConverter(fieldDelimiter: ',', eol: '\n').convert(raw);
    _csvRowsCache = rows;
    _csvHeaderCache = rows[0];
  }

  static List<List<dynamic>>? get csvRowsCache => _csvRowsCache;
  static List<dynamic>? get csvHeaderCache => _csvHeaderCache;

  static Future<CsvDateInfo> getAvailableDatesAndRange() async {
    await ensureCsvLoaded();
    final header = _csvHeaderCache!;
    final dateRegExp = RegExp(r'\d{2}/\d{2}/\d{4}');
    final dateColumns = header.where((h) => h is String && dateRegExp.hasMatch(h)).cast<String>().toList();
    final minDate = dateColumns.isNotEmpty ? parseCsvDate(dateColumns.first) : DateTime.now();
    final maxDate = dateColumns.isNotEmpty ? parseCsvDate(dateColumns.last) : DateTime.now();
    return CsvDateInfo(dateColumns, minDate, maxDate);
  }

  /// Loads cloud spots for a given date range and mushroom type.
  static Future<List<CloudSpot>> loadCloudSpots(String start, String end, String mushroomType) async {
    await ensureCsvLoaded();
    final rows = _csvRowsCache!;
    final header = _csvHeaderCache!;
    final latIndex = header.indexOf("LAT [°]");
    final lonIndex = header.indexOf("LON [°]");
    final quotaIndex = header.indexOf("Quota");
    final nameIndex = header.indexOf("Nome");
    final indexIndex = header.indexOf("index");
    final startIdx = header.indexOf(start);
    final endIdx = header.indexOf(end);
    final dateIndices = startIdx == endIdx
        ? [startIdx]
        : List.generate(endIdx - startIdx + 1, (i) => startIdx + i);

    // Use compute to run in background isolate
    final List<Map<String, dynamic>> rawSpots = await compute(computeCloudSpots, {
      'rows': rows,
      'header': header,
      'latIndex': latIndex,
      'lonIndex': lonIndex,
      'quotaIndex': quotaIndex,
      'nameIndex': nameIndex,
      'indexIndex': indexIndex,
      'dateIndices': dateIndices,
      'mushroomType': mushroomType,
    });

    // Map to CloudSpot and compute opacity on main thread
    double computeOpacity(double value) {
      if (value >= 100) return 0.5;
      if (value <= 10) return 0.0;
      return ((value - 10) / 90 * 0.5).clamp(0.0, 0.5);
    }

    return rawSpots.map((data) {
      final double opacity = computeOpacity(data['sumValue']);
      return CloudSpot(
        LatLng(data['lat'], data['lon']),
        opacity,
        '${data['name']}\nQuota: ${data['quota'].toStringAsFixed(1)} m\nCumulato: ${data['sumValue'].toStringAsFixed(1)} mm',
        data['sumValue'],
        index: data['index'],
      );
    }).toList();
  }
}
