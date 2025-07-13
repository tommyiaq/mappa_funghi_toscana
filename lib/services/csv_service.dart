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
  static List<List<dynamic>>? _tempCsvRowsCache;
  static List<dynamic>? _tempCsvHeaderCache;

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

  static Future<void> ensureTempCsvLoaded() async {
    if (_tempCsvRowsCache != null && _tempCsvHeaderCache != null) return;
    final response = await http.get(Uri.parse(
      'https://raw.githubusercontent.com/tommyiaq/privacy-policy/main/assets/temp_completi.csv',
    ));
    if (response.statusCode != 200) {
      throw Exception('Failed to load temperature CSV');
    }
    final raw = response.body;
    final rows = const CsvToListConverter(fieldDelimiter: ',', eol: '\n').convert(raw);
    _tempCsvRowsCache = rows;
    _tempCsvHeaderCache = rows[0];
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

  /// Gets average temperature for a station in the given date range
  /// Returns null if station is not found or data is not available
  static Future<double?> getAverageTemperature(String stationIndex, String start, String end) async {
    try {
      await ensureTempCsvLoaded();
      final rows = _tempCsvRowsCache!;
      final header = _tempCsvHeaderCache!;
      
      final indexIndex = header.indexOf("index");
      if (indexIndex == -1) return null;
      
      final startIdx = header.indexOf(start);
      final endIdx = header.indexOf(end);
      
      if (startIdx == -1 || endIdx == -1) return null;
      
      // Find the station row
      List<dynamic>? stationRow;
      for (final row in rows.skip(1)) {
        if (row[indexIndex]?.toString() == stationIndex) {
          stationRow = row;
          break;
        }
      }
      
      if (stationRow == null) return null;
      
      // First, check if this station has ANY non-zero temperature data in DATE columns only
      // If all date entries are 0.0, it means this station has no temperature sensors
      bool hasAnyTemperatureData = false;
      final dateRegExp = RegExp(r'\d{2}/\d{2}/\d{4}');
      
      for (int i = 0; i < header.length; i++) {
        // Only check columns that are date columns
        if (header[i] is String && dateRegExp.hasMatch(header[i])) {
          final value = stationRow[i];
          if (value != null && value != '' && value != 0 && value != 0.0) {
            final numValue = value is num ? value.toDouble() : double.tryParse(value.toString());
            if (numValue != null && numValue != 0.0) {
              hasAnyTemperatureData = true;
              break;
            }
          }
        }
      }
      
      print('Debug - Station $stationIndex: hasAnyTemperatureData = $hasAnyTemperatureData');
      
      // If station has no temperature data at all, return null
      if (!hasAnyTemperatureData) return null;
      
      // Calculate average temperature for the date range (now including 0.0 as valid readings)
      final dateIndices = startIdx == endIdx
          ? [startIdx]
          : List.generate(endIdx - startIdx + 1, (i) => startIdx + i);
      
      double sum = 0;
      int count = 0;
      
      for (final idx in dateIndices) {
        final value = stationRow[idx];
        if (value != null && value != '') {
          final numValue = value is num ? value.toDouble() : double.tryParse(value.toString());
          if (numValue != null) { // Now accept all numeric values including 0.0
            sum += numValue;
            count++;
          }
        }
      }
      
      return count > 0 ? sum / count : null;
    } catch (e) {
      // If there's any error loading temperature data, return null
      return null;
    }
  }

  /// Loads cloud spots for a given date range and mushroom type.
  /// For Home: calculates temperature for last 7 days from today
  /// For Archive: calculates temperature for the selected date range
  static Future<List<CloudSpot>> loadCloudSpots(
    String start, 
    String end, 
    String mushroomType, {
    bool isArchivio = false,
  }) async {
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

    // Calculate temperature date range based on context
    String tempStart, tempEnd;
    if (isArchivio) {
      // Archive: use selected date range, but shift to exclude last 2 days
      final startDate = parseCsvDate(start);
      final endDate = parseCsvDate(end);
      final adjustedStart = startDate.subtract(const Duration(days: 7)); // 9-2 = 7 days before start
      final adjustedEnd = endDate.subtract(const Duration(days: 2)); // exclude last 2 days
      tempStart = formatCsvDate(adjustedStart);
      tempEnd = formatCsvDate(adjustedEnd);
    } else {
      // Home: use last 9 days excluding the last 2 (so days -9 to -2)
      final now = DateTime.now();
      final nineDaysAgo = now.subtract(const Duration(days: 9));
      final twoDaysAgo = now.subtract(const Duration(days: 2));
      tempStart = formatCsvDate(nineDaysAgo);
      tempEnd = formatCsvDate(twoDaysAgo);
    }

    // Map to CloudSpot and compute opacity on main thread
    double computeOpacity(double value) {
      if (value >= 100) return 0.5;
      if (value <= 10) return 0.0;
      return ((value - 10) / 90 * 0.5).clamp(0.0, 0.5);
    }

    // Load temperature data for each station
    final List<CloudSpot> cloudSpots = [];
    for (final data in rawSpots) {
      final double opacity = computeOpacity(data['sumValue']);
      
      // Get average temperature for this station if available
      double? avgTemp;
      if (data['index'] != null && data['index'].isNotEmpty) {
        avgTemp = await getAverageTemperature(data['index'], tempStart, tempEnd);
      }
      
      // Build info string with temperature if available
      String info = '${data['name']}\nQuota: ${data['quota'].toStringAsFixed(1)} m\nCumulato: ${data['sumValue'].toStringAsFixed(1)} mm';
      if (avgTemp != null && avgTemp != 0.0) { // Don't show if temperature is null or exactly 0.0
        final tempLabel = isArchivio ? 'Temp. media periodo' : 'Temp. media (fruttificazione)';
        info += '\n$tempLabel: ${avgTemp.toStringAsFixed(1)}°C';
      }
      
      cloudSpots.add(CloudSpot(
        LatLng(data['lat'], data['lon']),
        opacity,
        info,
        data['sumValue'],
        index: data['index'],
        avgTemperature: avgTemp,
      ));
    }

    return cloudSpots;
  }
}
