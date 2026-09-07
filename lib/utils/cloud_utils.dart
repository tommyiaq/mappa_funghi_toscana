// Utility functions for cloud spot computation

/// Computes cloud spots from CSV data for use with compute().
///
/// Two modes:
///  * fixed window   - args['dateIndices'] holds the columns to sum. Used by
///                     Archivio, where the window is the range the user picked.
///  * sliding window - args['shiftByStation'] is present, so each station gets
///                     its own window: the base offsets moved later by that
///                     station's heat-driven shift. Used by Home.
List<Map<String, dynamic>> computeCloudSpots(Map<String, dynamic> args) {
  final List<List<dynamic>> rows = args['rows'];
  final int latIndex = args['latIndex'];
  final int lonIndex = args['lonIndex'];
  final int quotaIndex = args['quotaIndex'];
  final int nameIndex = args['nameIndex'];
  final int indexIndex = args['indexIndex'];

  final Map<String, int>? shiftByStation = args['shiftByStation'];
  // Sliding mode only: date columns in chronological order, plus where the
  // target date sits in that list and the base offsets relative to it.
  final List<int> orderedDateIndices =
      (args['orderedDateIndices'] as List?)?.cast<int>() ?? const [];
  final int targetPos = args['targetPos'] ?? -1;
  final int baseStart = args['baseStart'] ?? 0;
  final int baseEnd = args['baseEnd'] ?? 0;

  final List<int> fixedDateIndices =
      (args['dateIndices'] as List?)?.cast<int>() ?? const [];

  final bool sliding = shiftByStation != null && targetPos >= 0;

  /// Column indices to sum for one station.
  List<int> windowFor(String? station) {
    if (!sliding) return fixedDateIndices;
    final shift = shiftByStation[station] ?? 0;
    // Offsets are negative (days before the target), so adding the shift moves
    // the window later. Clamp to the data we actually have.
    var from = targetPos + baseStart + shift;
    var to = targetPos + baseEnd + shift;
    if (to < from) return const [];
    from = from.clamp(0, orderedDateIndices.length - 1);
    to = to.clamp(0, orderedDateIndices.length - 1);
    return [
      for (int p = from; p <= to; p++) orderedDateIndices[p],
    ];
  }

  final int fixedMax = [
    latIndex,
    lonIndex,
    quotaIndex,
    nameIndex,
    indexIndex,
    ...fixedDateIndices,
    ...orderedDateIndices,
  ].fold(0, (a, b) => a > b ? a : b);

  final List<Map<String, dynamic>> result = [];
  for (final row in rows.skip(1)) {
    if (row.length <= fixedMax) {
      continue;
    }
    if (row[latIndex] is! num) {
      // Skip rows where lat is not a number (e.g., header or malformed row)
      continue;
    }
    final String? index = indexIndex >= 0 ? row[indexIndex]?.toString() : null;

    final dateIndices = windowFor(index);
    if (dateIndices.isEmpty) continue;

    final double lat = (row[latIndex] as num).toDouble();
    final double lon = (row[lonIndex] as num).toDouble();
    final String name = row[nameIndex].toString();
    final double quota = (row[quotaIndex] as num?)?.toDouble() ?? 0.0;
    final sumValue = dateIndices.fold<double>(
        0, (sum, i) => sum + ((row[i] as num?)?.toDouble() ?? 0.0));

    result.add({
      'lat': lat,
      'lon': lon,
      'name': name,
      'quota': quota,
      'sumValue': sumValue,
      'index': index,
      'shift': sliding ? (shiftByStation[index] ?? 0) : 0,
    });
  }
  return result;
}

/// Computes the opacity for a cloud spot based on its value.
double computeOpacity(double value) {
  if (value >= 100) return 0.5;
  if (value <= 10) return 0.0;
  return ((value - 10) / 90 * 0.5).clamp(0.0, 0.5);
}
