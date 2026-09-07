import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../constants/app_constants.dart';
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

  /// Station id -> true when its temperature was interpolated (TempStimata=1).
  static Map<String, bool>? _estimatedCache;

  /// In-flight loads, shared by concurrent callers.
  static Future<void>? _csvLoading;
  static Future<void>? _tempCsvLoading;

  static final RegExp _dateColumn = RegExp(r'^\d{2}/\d{2}/\d{4}$');

  /// Porcini and Giallarelle load concurrently, so both used to find the cache
  /// empty and fetch the same file. Share the in-flight request instead, and
  /// drop it on completion so a failed load can still be retried.
  static Future<void> ensureCsvLoaded() {
    if (_csvRowsCache != null && _csvHeaderCache != null) return Future.value();
    return _csvLoading ??= _loadCsv().whenComplete(() => _csvLoading = null);
  }

  static Future<void> _loadCsv() async {
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

  static Future<void> ensureTempCsvLoaded() {
    if (_tempCsvRowsCache != null && _tempCsvHeaderCache != null) {
      return Future.value();
    }
    return _tempCsvLoading ??=
        _loadTempCsv().whenComplete(() => _tempCsvLoading = null);
  }

  static Future<void> _loadTempCsv() async {
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
    _estimatedCache = _readEstimatedFlags(rows);
  }

  static List<List<dynamic>>? get csvRowsCache => _csvRowsCache;
  static List<dynamic>? get csvHeaderCache => _csvHeaderCache;

  /// TempStimata is appended as the last column by the nightly interpolation
  /// step. Missing column means an older file: treat everything as measured.
  static Map<String, bool> _readEstimatedFlags(List<List<dynamic>> rows) {
    final header = rows[0];
    final flagIndex = header.indexOf('TempStimata');
    final indexIndex = header.indexOf('index');
    final out = <String, bool>{};
    if (flagIndex == -1 || indexIndex == -1) return out;
    for (final row in rows.skip(1)) {
      if (row.length <= flagIndex || row.length <= indexIndex) continue;
      final id = row[indexIndex]?.toString();
      if (id == null || id.isEmpty) continue;
      final raw = row[flagIndex];
      final value = raw is num ? raw.toInt() : int.tryParse(raw.toString()) ?? 0;
      out[id] = value == 1;
    }
    return out;
  }

  static Future<CsvDateInfo> getAvailableDatesAndRange() async {
    await ensureCsvLoaded();
    final header = _csvHeaderCache!;
    final dateColumns =
        header.where((h) => h is String && _dateColumn.hasMatch(h)).cast<String>().toList();
    final minDate = dateColumns.isNotEmpty ? parseCsvDate(dateColumns.first) : DateTime.now();
    final maxDate = dateColumns.isNotEmpty ? parseCsvDate(dateColumns.last) : DateTime.now();
    return CsvDateInfo(dateColumns, minDate, maxDate);
  }

  /// Mean of the daily mean temperatures over [start]..[end] inclusive.
  /// Returns null when the station or the columns are missing.
  static Future<double?> getAverageTemperature(
      String stationIndex, String start, String end) async {
    try {
      await ensureTempCsvLoaded();
      final rows = _tempCsvRowsCache!;
      final header = _tempCsvHeaderCache!;

      final indexIndex = header.indexOf("index");
      if (indexIndex == -1) return null;

      final startIdx = header.indexOf(start);
      final endIdx = header.indexOf(end);
      if (startIdx == -1 || endIdx == -1) return null;

      List<dynamic>? stationRow;
      for (final row in rows.skip(1)) {
        if (row[indexIndex]?.toString() == stationIndex) {
          stationRow = row;
          break;
        }
      }
      if (stationRow == null) return null;

      final dateIndices = startIdx == endIdx
          ? [startIdx]
          : List.generate(endIdx - startIdx + 1, (i) => startIdx + i);

      double sum = 0;
      int count = 0;
      for (final idx in dateIndices) {
        if (idx >= stationRow.length) continue;
        final value = stationRow[idx];
        // Empty means the day was never measured and could not be estimated;
        // skip it rather than counting it as 0 C.
        if (value == null || value == '') continue;
        final numValue =
            value is num ? value.toDouble() : double.tryParse(value.toString());
        if (numValue == null) continue;
        sum += numValue;
        count++;
      }
      return count > 0 ? sum / count : null;
    } catch (e) {
      return null;
    }
  }

  /// Date-only, so day arithmetic is not thrown off by a time component.
  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Date columns of a header, in the order they appear (chronological).
  static List<String> _dateColumnsOf(List<dynamic> header) => [
        for (final h in header)
          if (h is String && _dateColumn.hasMatch(h)) h,
      ];

  /// The last [count] date columns falling on or before [notAfter].
  ///
  /// The day selector offers today plus six days ahead, so the target is often
  /// beyond the data. Anchoring on the most recent available days keeps the
  /// temperature windows meaningful instead of silently empty.
  static List<String> _recentWindow(
      List<String> all, DateTime notAfter, int count) {
    final limit = _dayOf(notAfter);
    final eligible = [
      for (final c in all)
        if (!parseCsvDate(c).isAfter(limit)) c,
    ];
    if (eligible.isEmpty) return const [];
    return eligible.sublist(
        eligible.length > count ? eligible.length - count : 0);
  }

  /// How many days to slide each station's rain window, from its own recent
  /// mean temperature. Cool stations keep the base window, hot ones move it
  /// later. See AppConstants.tempPivotCelsius.
  static Future<Map<String, int>> computeWindowShifts(DateTime target) async {
    await ensureTempCsvLoaded();
    final rows = _tempCsvRowsCache!;
    final header = _tempCsvHeaderCache!;
    final indexIndex = header.indexOf('index');
    if (indexIndex == -1) return {};

    final window = _recentWindow(
      _dateColumnsOf(header),
      target.subtract(const Duration(days: 1)),
      AppConstants.refTempDays,
    );
    final columns = <int>[];
    for (final c in window) {
      final idx = header.indexOf(c);
      if (idx != -1) columns.add(idx);
    }
    if (columns.isEmpty) return {};

    final shifts = <String, int>{};
    for (final row in rows.skip(1)) {
      final id = row[indexIndex]?.toString();
      if (id == null || id.isEmpty) continue;

      double sum = 0;
      int count = 0;
      for (final idx in columns) {
        if (idx >= row.length) continue;
        final value = row[idx];
        if (value == null || value == '') continue;
        final numValue =
            value is num ? value.toDouble() : double.tryParse(value.toString());
        if (numValue == null) continue;
        sum += numValue;
        count++;
      }
      if (count == 0) continue;

      final refTemp = sum / count;
      final raw = (refTemp - AppConstants.tempPivotCelsius).round();
      shifts[id] = raw.clamp(0, AppConstants.maxWindowShiftDays);
    }
    return shifts;
  }

  /// Home: each station gets its own rain window, slid later by its own heat.
  static Future<List<CloudSpot>> loadCloudSpotsForDate(
    DateTime target,
    String mushroomType,
  ) async {
    await ensureCsvLoaded();
    final header = _csvHeaderCache!;

    final orderedDates = <String>[];
    final orderedIndices = <int>[];
    for (int i = 0; i < header.length; i++) {
      final h = header[i];
      if (h is String && _dateColumn.hasMatch(h)) {
        orderedDates.add(h);
        orderedIndices.add(i);
      }
    }
    if (orderedDates.isEmpty) return [];

    // The target is frequently NOT a column: the day selector offers today
    // plus six days ahead, and the newest complete day may be yesterday. So
    // locate it by counting days from the last column rather than looking it
    // up, which lets targetPos sit past the end. The window is what has to
    // land inside the data, and computeCloudSpots clamps it.
    final lastDate = parseCsvDate(orderedDates.last);
    final targetPos = (orderedDates.length - 1) +
        _dayOf(target).difference(lastDate).inDays;

    final baseStart = mushroomType == 'Porcini'
        ? -AppConstants.porciniDateOffsetStart
        : -AppConstants.giallarelleeDateOffsetStart;
    final baseEnd = mushroomType == 'Porcini'
        ? -AppConstants.porciniDateOffsetEnd
        : -AppConstants.giallarelleeDateOffsetEnd;

    final shifts = await computeWindowShifts(target);

    return _buildSpots(
      mushroomType: mushroomType,
      isArchivio: false,
      target: target,
      extraArgs: {
        'shiftByStation': shifts,
        'orderedDateIndices': orderedIndices,
        'targetPos': targetPos,
        'baseStart': baseStart,
        'baseEnd': baseEnd,
      },
    );
  }

  /// Archivio: the window is exactly the range the user picked, for every
  /// station. Unchanged behaviour.
  static Future<List<CloudSpot>> loadCloudSpots(
    String start,
    String end,
    String mushroomType, {
    bool isArchivio = false,
  }) async {
    await ensureCsvLoaded();
    final header = _csvHeaderCache!;
    final startIdx = header.indexOf(start);
    final endIdx = header.indexOf(end);
    if (startIdx == -1 || endIdx == -1) return [];
    final dateIndices = startIdx == endIdx
        ? [startIdx]
        : List.generate(endIdx - startIdx + 1, (i) => startIdx + i);

    return _buildSpots(
      mushroomType: mushroomType,
      isArchivio: isArchivio,
      rangeStart: start,
      rangeEnd: end,
      extraArgs: {'dateIndices': dateIndices},
    );
  }

  static Future<List<CloudSpot>> _buildSpots({
    required String mushroomType,
    required bool isArchivio,
    required Map<String, dynamic> extraArgs,
    DateTime? target,
    String? rangeStart,
    String? rangeEnd,
  }) async {
    final rows = _csvRowsCache!;
    final header = _csvHeaderCache!;

    final List<Map<String, dynamic>> rawSpots = await compute(computeCloudSpots, {
      'rows': rows,
      'header': header,
      'latIndex': header.indexOf("LAT [°]"),
      'lonIndex': header.indexOf("LON [°]"),
      'quotaIndex': header.indexOf("Quota"),
      'nameIndex': header.indexOf("Nome"),
      'indexIndex': header.indexOf("index"),
      'mushroomType': mushroomType,
      ...extraArgs,
    });

    await ensureTempCsvLoaded();

    // Temperature window for the fruttificazione mean.
    String tempStart;
    String tempEnd;
    if (isArchivio && rangeStart != null && rangeEnd != null) {
      final startDate = parseCsvDate(rangeStart);
      final endDate = parseCsvDate(rangeEnd);
      tempStart = formatCsvDate(startDate.subtract(const Duration(days: 7)));
      tempEnd = formatCsvDate(endDate.subtract(const Duration(days: 2)));
    } else {
      // Nominally days -9..-2, but for a forecast day those run into the
      // future. Fall back to the most recent 8 available days, otherwise the
      // temperature would be null and the filter would pass everything.
      final base = target ?? DateTime.now();
      final window = _recentWindow(
        _dateColumnsOf(_tempCsvHeaderCache!),
        base.subtract(const Duration(days: 2)),
        8,
      );
      if (window.isEmpty) return [];
      tempStart = window.first;
      tempEnd = window.last;
    }

    final estimated = _estimatedCache ?? const <String, bool>{};

    final List<CloudSpot> cloudSpots = [];
    for (final data in rawSpots) {
      final double opacity = computeOpacity(data['sumValue']);

      double? avgTemp;
      final String? id = data['index'];
      if (id != null && id.isNotEmpty) {
        avgTemp = await getAverageTemperature(id, tempStart, tempEnd);
      }
      final bool isEstimated = id != null && (estimated[id] ?? false);

      String info =
          '${data['name']}\nQuota: ${data['quota'].toStringAsFixed(1)} m\nCumulato: ${data['sumValue'].toStringAsFixed(1)} mm';
      if (avgTemp != null) {
        final tempLabel = isArchivio ? 'Temp. media periodo' : 'Temp. media (fruttificazione)';
        final suffix = isEstimated ? ' (stimata)' : '';
        info += '\n$tempLabel: ${avgTemp.toStringAsFixed(1)}°C$suffix';
      }

      cloudSpots.add(CloudSpot(
        LatLng(data['lat'], data['lon']),
        opacity,
        info,
        data['sumValue'],
        index: id,
        avgTemperature: avgTemp,
        isEstimatedTemperature: isEstimated,
        windowShiftDays: data['shift'] ?? 0,
      ));
    }

    return cloudSpots;
  }
}
